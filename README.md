# Convert videos to h265 (HEVC)

So this is a simple ruby script that will chuch through a directory converting all of the videos to be h.265 in place.  This works by converting the video file to \*.tmp.mp4, and then moving it to its original file name with the mp4 extension.  It will delete the old version of the file.  


## Usage

This is a long running ruby script, it makes calls to FFMPEG using a ruby gem to scrape metadata of videos, and transcode them.  It works by appling some simple filters to create a queue of videos that can be converted, and then works through that queue.  

|Constant| Description|
|--|--|
|DIRECTORY | the directory to recurse into.  All files will be considered within that directory. |
|MIN_AGE_DAYS| How long agos does the ctime on a file have to be to be considered.  This is useful when using flexget to orgonize your movies/series and a torrent client might still be seeding the file.  |
|VID_FORMATS| Possible file endings to consider.  The current value should sufice for most use cases |
|LOG_LOCATION|  This Script is designed to run deetached in the background.  As such the log location is the best way to figure out whatis going on and the status of the conversion|  
| PRESET | used to trade off between final file size, quality, and transcoding time. I recomend fast.|


## Logic

1. Create a queue of videos that are at least MIN_AGE_DAYS old, a video file, and not encoded with h265 or HEVC already.
2. Go through that queue one item at a time and transcode that file to HEVC, keeping the audio track in place.  (May remove embeeded subtitles)
3. Probably never finish, because lets face it, you have a lot of movies

There are two important side effects of this.  The script is effecivaly stateless so nothing is stored between runs beyond the files themselves. And, the age of files is based on when the script starts, so that list will always be stale.  

## Setup

1. Instal Ruby 2.1.0+
2. Install (ffmpeg)[https://ffmpeg.org/download.html] near version 2.5.10
3. gem install 'streamio-ffmpeg'
4. Optional: Install screen or tmux. This is to allow it to run in the background after closing SSH on a server.
5. Edit the script.
6. Run the script.
7. Automate/cron?
