# Convert videos to h265 (HEVC)

So this is a simple ruby script that will chuch through a directory converting all of the videos to use h.265 or HEVC in place.  This works by converting the video file to \*.tmp.mp4, and then moving it to its original file name with the mp4 extension.  It will delete the old version of the file.  


## Usage

This is a long running ruby script, it makes calls to FFMPEG using a ruby gem to scrape metadata of videos, and transcode them.  It works by appling some simple filters to create a list of videos that can be converted, and then works through that queue.

Move to the directory where the config is located and run: `ruby convertMovies.rb start`

## Example Config
Please note the preceding colons are important.  Also the file must be called config.yml

```
:min_age_days: 5
:directory: /home/user/videos/movies
:log_location: /home/user/logs/HevcConversion.log
:preset: slow
:max_new_file_size_ratio: 0.9
```


|Constant| Description|
|--|--|
|directory | the directory to recurse into.  All files will be considered within that directory. |
|min_age_days | How many days old does this file have to be to be considered for conversion.  |
|log_location|  This Script is designed to run deetached in the background.  As such the log location is the best way to figure out whatis going on and the status of the conversion |  
| preset | used to trade off between final file size, quality, and transcoding time. I recomend slow.  See ffmpeg docs for more detail. |
|max_new_file_size_ratio| Once transocing is finished, this script will make sure the output is smaller than the origional.  Spesifically new file size <= Old file size * this value.  Since transcoding always involves quality loss this value should be less than 1.0 |


## Coridnation
When this script starts to convert a video, it creates a .filename.tmp.mp4 file that used the old files filename.  This acts as kind of a lock because the exitsance of that file is checked before conversion.  This also allows us to save state between runs without needing to share a database or other coridination servcie.  That file is left behind if, for any reason, the conversion fails, the process is stopped, or if afterthe conversion the new HEVC file is not at least 10% smaller than the origional.  The content is replace with an explination if possible.

It also makes it so multiple computers can run this script, provided they are all run against the same backing file system (SMB, NFS, etc.).



## Disclaimers
- Only use with videos you have the rights to copy
- This will delete the original video, so use with care.  Test with a test directory before running on your entire library.  
- Use a test file with all your media playing devices to ensure that they can handle HEVC encoding.  Raspberry pies, both 1 and 2 are not able to handle HEVC decoding.
