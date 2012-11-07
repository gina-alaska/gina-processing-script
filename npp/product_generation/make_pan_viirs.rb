#!/usr/bin/env ruby
require "trollop"
require "fileutils"
#############
# Simple command to run several things at once
# ./make_pan_viirs.rb -h is your friend/fiend


#wrapper for system - runs command on task
def runner ( command, opts)
  puts("Info: Running: #{command}") if (opts[:verbrose])
  start_time = Time.now
  system(command)
  puts("Info: Done in #{(Time.now - start_time)/60.0}m.") if (opts[:verbrose])
end

def get_band (color )
  puts ("Looking for npp*#{color}*_float.tif")
  band = Dir.glob("npp*#{color}*_float.tif")
  raise(RuntimeError, "Too many bands found ({green.join(",")} for band #{color}") if (band.length > 1)
  raise(RuntimeError,"No bands found for band #{color}") if (band.length == 0)
  band.first
end


## Command line parsing action..
parser = Trollop::Parser.new do
  version "0.0.1 jay@alaska.edu"
  banner <<-EOS
  This util makes pan banded action from viirs data from pytroll.  

Usage:
      make_pan_viirs.rb [options] <viirs dir> 
where [options] is:
EOS

  opt :red, "red band", :default =>  "M05"
  opt :green, "green band", :default =>  "M04"
  opt :blue, "blue band", :default =>  "M03"
  opt :pan, "pan band", :default => "none"
  opt :verbrose, "Maxium Verbrosity.", :short => "V"
  opt :dry_run, "Don't actually run the command(s)"
end

opts = Trollop::with_standard_exception_handling(parser) do
  o = parser.parse ARGV
  raise Trollop::HelpNeeded if ARGV.length != 1 # show help screen
  o
end

contrast_options = "-ndv '0.99995..1' -ndv 0.0 -linear-stretch 128 50 -outndv 0 "
gdal_opts = "-co TILED=YES -co COMPRESS=LZW -a_nodata \"0 0 0\" "

FileUtils.cd(ARGV[0]) do
  tmp_name = opts[:red] + "_" + opts[:green] + "_" + opts[:blue] + "_" + ".tmp"
  red = get_band(opts[:red])
  green = get_band(opts[:green])
  blue = get_band(opts[:blue])
  runner("gdalbuildvrt -resolution highest -separate #{tmp_name}.vrt #{red} #{green} #{blue}", opts)
  runner("gdal_contrast_stretch #{contrast_options} #{tmp_name}.vrt #{tmp_name}.tif", opts)

  final_file = ""
  temp_file = ""
  if ( opts[:pan] != "none" )
    temp_file = tmp_name + "_" + opts[:pan]
    final_file = File.basename(get_band(opts[:pan])).split("_").first + "_" + opts[:red] + "_" + opts[:green] + "_" + opts[:blue] + "_" + opts[:pan] 
    pan = get_band(opts[:pan])
    runner("gdal_contrast_stretch #{contrast_options} #{pan} #{pan}.tmp", opts)
    runner("gdal_landsat_pansharp -ndv 0 -rgb #{tmp_name}.tif -pan #{pan}.tmp -o #{temp_file}.tif", opts)
    runner("rm -v #{pan}.tmp", opts)
  else
    temp_file = tmp_name 
    final_file = File.basename(get_band(opts[:red])).split("_").first + "_" + opts[:red] + "_" + opts[:green] + "_" + opts[:blue] 
  end
  runner("gdal_translate #{gdal_opts} #{temp_file}.tif #{final_file}.tif ", opts)
  runner("add_overviews.rb #{final_file}.tif ", opts)
  runner("rm -v #{temp_file}.tif #{tmp_name}.vrt #{tmp_name}.tif", opts)
  runner("gdal_translate -of png -outsize 1000 1000 #{final_file}.tif #{final_file}.small.png", opts)
end
