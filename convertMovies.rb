

# Author: Erik

require 'rubygems'
require 'streamio-ffmpeg'
require 'fileutils'
require 'logger'

DIRECTORY=  '/home/eh/git/convertTo265/test'

# "/mnt/nasData/movies"
MIN_AGE_DAYS=0
VID_FORMATS = %w[.avi .flv .mkv .mov .mp4]
LOG_LOCATION = "#{ENV['HOME']}/HevcConversion.log"
PRESET='ultrafast'
LOGGER=Logger.new(LOG_LOCATION)
LOGGER.level=Logger::INFO


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
    next if file == '.' or file == '..'
    fileName=File.join(directory,file)
    if(File.file?(fileName)) then
      if VID_FORMATS.include? File.extname(file) then
        if(file_age(fileName)>=MIN_AGE_DAYS) then
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
  possibileFiles.each do |file|
    if does_video_need_conversion?(file)
      out[:movies]<< file
      movie=FFMPEG::Movie.new(file)
      out[:runtime]=out[:runtime]+movie.duration
    end
  end
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

def convert_file(original_video,filename)
  options={
    video_codec: 'libx265',
    threads: 4,
    custom: "-preset #{PRESET} -crf 22 -c:a copy"
    }
  outFileName = get_base_name(filename)
  error_thrown=nil
  begin
    out = original_video.transcode(get_temp_filename(filename),options)
  rescue StandardError => e
    error_thrown=e
  end
  if(out && out.size<original_video.size*0.9)
    FileUtils.mv(get_temp_filename(filename),"#{outFileName}.mp4")
    if filename!="#{outFileName}.mp4" then
      FileUtils.rm(filename)
    end
    return out
  elsif (out.size<original_video.size*0.9)
    LOGGER.warn "A video file, after transcoding was not at least 90% the size of the origional.  Keeping origonal #{filename}"
    FileUtils.rm(get_temp_filename(filename))
    FileUtils.touch(get_temp_filename(filename))
    File.write(get_temp_filename(filename), 'transcoded video not enough smaller than the origional.')
    return original_video
  else
    LOGGER.error "A video file failed to transcode correctly"
    LOGGER.error error_thrown
    FileUtils.rm(get_temp_filename(filename))
    FileUtils.touch(get_temp_filename(filename))
    File.write(get_temp_filename(filename),
    [
      'An exception occured while transocding this movie.',
      error_thrown
    ].join('\n'))
  end
end

@total_processing_time=0
@processed_video_duration=0
def iterate
  possible_files=get_aged_files(DIRECTORY)
  LOGGER.info "There are a total of #{possible_files.size} files that may need to be converted."

  LOGGER.debug "Files to be checked: #{possible_files}"

  candidate_files= get_candidate_files(possible_files)

  LOGGER.info "There are a total of #{candidate_files[:movies].size} files that have not been converted yet."
  LOGGER.debug "Candidate Files that need to be re-encoded: #{candidate_files}"
  LOGGER.info "Total Duration: #{seconds_to_s(candidate_files[:runtime])}"
  remaining_runtime=candidate_files[:runtime]


  candidate_files[:movies].each_with_index do |file,index|
    LOGGER.info "Starting to transcode file #{index+1} of #{candidate_files[:movies].size}: #{file}"
    unless does_video_need_conversion?(file)
      LOGGER.info "Video already converted, scanning again"
      return true
    end
    startTime=Time.now
    video=FFMPEG::Movie.new(file)
    converted_video=convert_file(video,file)
    duration=Time.now - startTime
    remaining_runtime-=video.duration
    if !converted_video.nil? then
      @total_processing_time+=duration
      @processed_video_duration+=video.duration
    end
    avg=@processed_video_duration/@total_processing_time
    LOGGER.info "Average videotime/walltime: #{avg}  Estimated time remaining #{seconds_to_s(remaining_runtime/avg)}"
  end
  return false
end


while iterate do end
