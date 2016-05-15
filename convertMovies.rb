
require 'rubygems'
require 'streamio-ffmpeg'
require 'fileutils'

directory=  '/home/eh/git/convertTo265/test'
# "/mnt/nasData/movies"
MIN_AGE_DAYS=0
VID_FORMATS = %w[.avi .flv .mkv .mov .mp4]



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

possible_files=get_aged_files(directory)

candidate_file= get_candidate_file(possible_files)

while !candidate_file.nil? do
  puts candidate_file
  convert_file(candidate_file)
  candidate_file= get_candidate_file(possible_files)
end
