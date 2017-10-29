
# Author: Erik

require 'rubygems'
require 'streamio-ffmpeg'
require 'fileutils'
require 'logger'
require 'yaml'
require 'peach'

VID_FORMATS = %w[.avi .flv .mkv .mov .mp4]

@config=YAML.load(File.read("./HevcConfig.yml"))

@logger=Logger.new(@config[:log_location])
@logger.level=Logger::INFO

@logger.info "\n New Run starting now......"
@logger.info "Config being used: #{@config}"

def file_age(name)
  (Time.now - File.ctime(name))/(24*3600)
end

def seconds_to_s(total_time)
  total_time=total_time.to_int
  return [total_time / 3600, total_time/ 60 % 60, total_time % 60].map { |t| t.to_s.rjust(2,'0') }.join(':')
end

def get_aged_files(directory)
  out=[]
  Dir.foreach(directory){|file|
    next if file == '.' or file == '..' or file.start_with?('.')
    fileName=File.join(directory,file)
    if(File.file?(fileName)) then
      if VID_FORMATS.include? File.extname(file) then
        if(file_age(fileName)>=@config[:min_age_days]) then
          out<<fileName
        end
      end
    elsif File.directory?(fileName) then
      out+=get_aged_files(fileName)
    end
  }
  return out
end

# Returns a hash
def get_candidate_files(possibileFiles)
  out={
    movies: [],
    runtime: 0
  }
  times=[]
  possibileFiles.peach(4) do |file|
    if does_video_need_conversion?(file)
      out[:movies]<<file
      movie=FFMPEG::Movie.new(file)
      times<<movie.duration
    end
  end
  times.each{|time|
    out[:runtime]=out[:runtime]+=time
  }
  out[:movies].shuffle!
  return out
end

def does_video_need_conversion?(file)
  movie=FFMPEG::Movie.new(file)
  if movie.valid? then
    if movie.video_codec!="hevc" then
      unless File.exist?(get_temp_filename(file))
        return true
      end
    end
  end
  return false
end

def get_base_name(file)
  outFileName=File.join(
    File.dirname(file),
    "#{File.basename(file,'.*')}")
end

def get_temp_filename(file)
  "#{File.join(
    File.dirname(file),
    ".#{File.basename(file,'.*')}")}.tmp.mp4"
end

def safe_convert_file(original_video,filename)
  begin
    return convert_file(original_video,filename)
  rescue StandardError => e
    @logger.error "Problem processing a video",e
  end
  return nil
end

def convert_file(original_video,filename)
  options={
    video_codec: 'libx265',
    threads: @config[:threads],
    custom: "-preset #{@config[:preset]} -c:a copy".split
    }
  outFileName = get_base_name(filename)
  error_thrown=nil
  begin
    startTime=Time.now
    out = original_video.transcode(get_temp_filename(filename),options){ |progress|
      duration=Time.now-startTime
      remaining=(duration/progress)*(1-progress)
      if(remaining>99999999) then
        print "Progress converting #{filename.split('/').last} : #{(progress*100).round(1)}%                                  \r"
      else
        print "Progress converting #{filename.split('/').last} : #{(progress*100).round(1)}%  ETA is #{seconds_to_s(remaining)} \r"
      end
    }
  rescue StandardError => e
    error_thrown=e
    puts e.to_s
  end
  puts "Done with #{filename.split('\\').last}"
  if ( error_thrown )
    @logger.error "A video file failed to transcode correctly"
    @logger.error error_thrown
    FileUtils.rm(get_temp_filename(filename)) if File.exists?(get_temp_filename(filename))
    FileUtils.touch(get_temp_filename(filename))
    File.write(get_temp_filename(filename),
    [
      'An exception occured while transocding this movie.',
      error_thrown
    ].join('\n'))
  elsif (out.size>original_video.size*@config[:max_new_file_size_ratio])
    @logger.warn "A video file, after transcoding was not at least #{@config[:max_new_file_size_ratio]} the size of the origional (new: #{out.size} old: #{original_video.size}).  Keeping origonal #{filename}"
    FileUtils.rm(get_temp_filename(filename))
    FileUtils.touch(get_temp_filename(filename))
    File.write(get_temp_filename(filename), "transcoded video not enough smaller than the origional.")
    return original_video
  else
    FileUtils.mv(get_temp_filename(filename),"#{outFileName}.mp4")
    if filename!="#{outFileName}.mp4" then
      FileUtils.rm(filename)
    end
    return out
  end
end
def status(app)
  possible_files=get_aged_files(@config[:directory])
  puts "There are a total of #{possible_files.size} files that may need to be converted."

  candidate_files= get_candidate_files(possible_files)

  puts "There are a total of #{candidate_files[:movies].size} files that have not been converted yet."
  puts "Total Duration: #{seconds_to_s(candidate_files[:runtime])}"
end
@total_processing_time=0
@processed_video_duration=0
def iterate
  possible_files=get_aged_files(@config[:directory])
  @logger.info "There are a total of #{possible_files.size} files that may need to be converted."

  @logger.debug "Files to be checked: #{possible_files}"

  candidate_files= get_candidate_files(possible_files)

  @logger.info "There are a total of #{candidate_files[:movies].size} files that have not been converted yet."
  @logger.debug "Candidate Files that need to be re-encoded: #{candidate_files}"
  @logger.info "Total Duration: #{seconds_to_s(candidate_files[:runtime])}"
  remaining_runtime=candidate_files[:runtime]


  candidate_files[:movies].each_with_index do |file,index|
    @logger.info "Starting to transcode file #{index+1} of #{candidate_files[:movies].size}: #{file}"
    unless does_video_need_conversion?(file)
      @logger.info "Video already converted, scanning again"
      return true
    end
    startTime=Time.now
    video=FFMPEG::Movie.new(file)
    converted_video=safe_convert_file(video,file)
    duration=Time.now - startTime
    remaining_runtime-=video.duration
    if !converted_video.nil? then
      @total_processing_time+=duration
      @processed_video_duration+=video.duration
    end
    avg=@processed_video_duration/@total_processing_time
    @logger.info "Average videotime/walltime: #{avg}  Estimated time remaining #{seconds_to_s(remaining_runtime/avg)}"
  end
  return false
end

while iterate do end
