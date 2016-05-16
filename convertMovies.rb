

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
PRESET='fast'
statusLogger=Logger.new(LOG_LOCATION)
statusLogger.level=Logger::INFO


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
    movie=FFMPEG::Movie.new(file)
    if movie.valid? then
      if movie.video_codec!="hevc" then
        out[:movies]<< file
        out[:runtime]=out[:runtime]+movie.duration
      end
    end
  end
  out[:movies].sort!
  return out
end

def convert_file(video,filename)
  options={
    video_codec: 'libx265',
    threads: 3,
    custom: "-preset #{PRESET} -x265-params \"--tune fastdecode\" -crf 22 -c:a copy"
    }
  outFileName=File.join(
    File.dirname(filename),
    "#{File.basename(filename,'.*')}")
  out=video.transcode("#{outFileName}.tmp.mp4",options)
  FileUtils.mv("#{outFileName}.tmp.mp4","#{outFileName}.mp4")
  if filename!="#{outFileName}.mp4" then
    FileUtils.rm(filename)
  end
  return out
end

possible_files=get_aged_files(DIRECTORY)
statusLogger.info "There are a total of #{possible_files.size} files that may need to be converted."

statusLogger.debug "Files to be checked: #{possible_files}"

candidate_files= get_candidate_files(possible_files)

statusLogger.info "There are a total of #{candidate_files[:movies].size} files that have not been converted yet."
statusLogger.debug "Candidate Files that need to be re-encoded: #{candidate_files}"
statusLogger.info "Total Duration: #{seconds_to_s(candidate_files[:runtime])}"
remaining_runtime=candidate_files[:runtime]
total_processing_time=0
processed_video_duration=0

candidate_files[:movies].each_with_index do |file,index|
  statusLogger.info "Starting to transcode file #{index+1} of #{candidate_files[:movies].size}: #{file}"
  startTime=Time.now
  video=FFMPEG::Movie.new(file)
  converted_video=convert_file(video,file)
  duration=Time.now - startTime
  remaining_runtime-=video.duration
  if !converted_video.nil? then
    total_processing_time+=duration
    processed_video_duration+=video.duration
  end
  avg=processed_video_duration/total_processing_time
  statusLogger.info "Average videotime/walltime: #{avg}  Estimated time remaining #{seconds_to_s(remaining_runtime/avg)}"
end
