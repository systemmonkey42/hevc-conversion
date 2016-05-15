

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
statusLogger=Logger.new(LOG_LOCATION)
statusLogger.level=Logger::INFO


def file_age(name)
  (Time.now - File.ctime(name))/(24*3600)
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

def get_candidate_file(possibileFiles)
  possibileFiles.each do |file|
    movie=FFMPEG::Movie.new(file)
    if movie.valid? then
      if movie.video_codec!="hevc" then
        return file
      else
        puts "Found an already converted file: #{file}"
      end
    else
      puts "File not a movie: #{file}"
    end
  end
  return nil
end

def get_candidate_files(possibileFiles)
  out=[]
  possibileFiles.each do |file|
    movie=FFMPEG::Movie.new(file)
    if movie.valid? then
      if movie.video_codec!="hevc" then
        out<< file
      end
    end
  end
  return out
end

def convert_file(filename)
  video=FFMPEG::Movie.new(filename)
  options={
    video_codec: 'libx265',
    threads: 3,
    custom: "-preset slow -c:a copy"
    }
  outFileName=File.join(
    File.dirname(filename),
    "#{File.basename(filename,'.*')}")
  puts outFileName
  out=video.transcode("#{outFileName}.tmp.mp4",options)
  FileUtils.mv("#{outFileName}.tmp.mp4","#{outFileName}.mp4")
  if filename!="#{outFileName}.mp4" then
    FileUtils.rm(filename)
  end
end

possible_files=get_aged_files(DIRECTORY)
statusLogger.info "There are a total of #{possible_files.size} files that may need to be converted."

statusLogger.debug "Files to be checked: #{possible_files}"

candidate_files= get_candidate_files(possible_files)

statusLogger.info "There are a total of #{candidate_files.size} files that have not been converted yet."
statusLogger.debug "Candidate Files that need to be re-encoded: #{possible_files}"

candidate_files.each_with_index do |file,index|
  statusLogger.info "Starting to transcode file #{index+1} of #{candidate_files.size}: #{file}"
  convert_file(file)
end
