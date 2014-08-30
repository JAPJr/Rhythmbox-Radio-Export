#!/usr/bin/ruby

class Rhythmbox_db
  def initialize(file)
    @file = file
  end
  
  def find_records(type)
    record_pointers=[]
    nline = 0
    while !@file.eof?
      start_found = false
      while !start_found && !@file.eof?
        aline = @file.readline.chomp
        nline += 1
        if aline.match("  <entry type=\""+type+"\">")
          first_line = nline
          start_found = true
        end
      end
      end_found = false
      while !end_found && !@file.eof?
        aline = @file.readline.chomp        
        nline += 1
        if aline.match(/  <\/entry>/)
        	last_line = nline
        	end_found = true
        end
      end
      record_pointers << [first_line, last_line] if start_found && end_found
    end
    @file.rewind
    record_pointers
  end  

  def get_record(start, stop)
    preceding_lines = start-1
    preceding_lines.times {@file.readline}
    record = []
    no_lines = stop-preceding_lines
    no_lines.times {record << @file.readline.chomp}
    @file.rewind
    record
  end
 
  def save_old_radio_records(radio_db)
    old_station_pointers = find_records("iradio")
    nline = 1
    old_station_pointers.each do |location|
      move = location[0]-nline
      move.times {@file.readline}
      nline += move
      record_length = location[1]-location[0]+1
      record_length.times {radio_db.puts @file.readline.chomp}
      nline += record_length
    end
    @file.rewind
    radio_db.rewind
  end

  
  def copy_block(start, stop, to_file)
    skip_lines = start - 1
    skip_lines.times {@file.readline}
    if stop == "eof"
      to_file.puts @file.readline.chomp while !@file.eof? 
    else
      n_lines = stop - start + 1
      n_lines.times {to_file.puts @file.readline.chomp}
    end
    @file.rewind
  end

  def get_station_list
    station_list = []
    while !@file.eof
      aline = @file.readline.chomp
      if aline == "  <entry type=\"iradio\">"
  	    station_list << @file.readline.slice(/>(.+)</,1)
      end
    end
    @file.rewind
    station_list
  end
  
  def add_unique_stations(radio_db, to_file)
    stations = get_station_list
    puts "\n\nStations in new data base:"
    stations.each {|station| puts station}
    pointers = radio_db.find_records("iradio")
    puts 
    puts "\n\nStations in old data base:"
    pointers.each do |location|
      start = location[0]
      stop = location[1]
      station_record = radio_db.get_record(start, stop)
      station_name = station_record[1].slice(/>(.+)</,1)
      puts station_name
      if !stations.include?(station_name)
        to_file.puts station_record
      end
      to_file.rewind
    end
  end
  
end



def get_file_name(querry)
  print querry + " (to abort type 'exit'):  "
  name = gets.chomp
  while !File.file?(name)
    exit if name.downcase == "exit"
    puts "File does not exist.  Enter a valid file or enter 'exit' to terminate:  "
    name = gets.chomp
  end
  name
end

 #Open rhythmbox data base files
 import_from = get_file_name("Old data base file to import radio stations from")
 old_file = open(import_from, "r")
 merge_with = get_file_name("New data base file to merge with")
 new_file = open(merge_with, "r")
 
#old_file = open("rhythmdb.xml", "r")
#new_file = open("newrhythmdb.xml", "r")

 #Open temporary file to store old radio stations records and file for final merged data base
radio_only_file = open("temp.xml", "w+")
merged_file = open("merged_rhythmdb.xml", "a")

 #Create data base objects
import_db = Rhythmbox_db.new(old_file)
new_db = Rhythmbox_db.new(new_file)

 #Save new Rhythmbox data base up to end of last radio station record
pointers = new_db.find_records("iradio")
block_beginning = 1
block_ending = pointers.last[1]
new_db.copy_block(block_beginning, block_ending, merged_file)

 #Add radio stations from old Rhythmbox data base
import_db.save_old_radio_records(radio_only_file)
old_stations_db = Rhythmbox_db.new(radio_only_file)
new_db.add_unique_stations(old_stations_db, merged_file)

 #Save remainder of new Rhythmbox data base
pointers = new_db.find_records("iradio")
block_beginning = pointers.last[1] + 1
new_db.copy_block(block_beginning, "eof", merged_file)
puts "\n\nResult of imported radio stations merged with new Rhythmbox data base is in file 'merged_rhythmdb.xml'"

old_file.close
new_file.close
radio_only_file.close
merged_file.close
File.delete "temp.xml"







  