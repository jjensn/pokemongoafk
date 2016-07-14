require 'nokogiri'
require 'time'
require 'cri'

def distance loc1, loc2 
  # shameless steal from http://stackoverflow.com/questions/12966638/how-to-calculate-the-distance-between-two-gps-coordinates-without-using-google-m
  rad_per_deg = Math::PI/180  # PI / 180
  rkm = 6371                  # Earth radius in kilometers
  rm = rkm * 1000             # Radius in meters

  dlat_rad = (loc2[0]-loc1[0]) * rad_per_deg  # Delta, converted to rad
  dlon_rad = (loc2[1]-loc1[1]) * rad_per_deg

  lat1_rad, lon1_rad = loc1.map {|i| i * rad_per_deg }
  lat2_rad, lon2_rad = loc2.map {|i| i * rad_per_deg }

  a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
  c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))

  rm * c # Delta in meters
end

def main path, speed, out
  if !File.file?(path)
    puts "error, #{path} not found, exiting..."
    exit(1)
  end
  
  if out.nil?
    puts "error, no output file specified, exiting..."
    exit(1)
  end
  
  xml_file = File.read("#{path}")
  
  doc = Nokogiri::XML.parse(xml_file)
  
  doc.remove_namespaces! # stupid namespaces always slowing me down
  
  # avg male = 3.7 m/s 
  # avg female = 2.9 m/s
  # usain bolt = 12.4 m/s
  # theorhetical max to get credit for eggs = 4.1 m/s
  
  t = Time.new()
  
  last_lat = 0.0
  last_lon = 0.0
  last_time = 0
  
  doc.xpath('/gpx[@version="1.0"]/wpt').each_with_index do |waypoint, index|  
    if index == 0
      time = t
    else
      dist = distance [last_lat, last_lon], [waypoint.xpath('@lat').text.to_f, waypoint.xpath('@lon').text.to_f] # meters between two points
      calc_time = (dist / speed).ceil # meters / avg meters per second
      time = Time.at(last_time + calc_time)
    end
    
    time_node = Nokogiri::XML::Node.new("time", doc)
    time_node.content = "#{time.utc.iso8601}"
    
    waypoint << time_node
    
    last_lat = waypoint.xpath('@lat').text.to_f
    last_lon = waypoint.xpath('@lon').text.to_f
    last_time = time.to_i
  end
  File.write(out, doc.to_xml)
  puts "success, file saved at #{File.expand_path(out)}, goodbye."
  exit(0)
end

command = Cri::Command.define do
  name        'pokemongoafk.rb'
  usage       'ruby pokemongoafk.rb [options] [gpx path] [output file]'
  summary     'adds timestamps to a generated gpx file'
  description 'pokemongoafk is a tool designed to add timestamps into generated gpx files. users then can use these files to bot around pokemon go using xcode.'

  required :s, :speed, 'the speed to travel between points, in meters per second (ex: 3.7)'
  flag :h, :help, 'shows this help screen'
  
  run do |opts, args|
    if opts[:help]
      puts command.help
      exit(0)
    end
    main args[0], opts[:speed].to_f, args[1]
  end
end

command.run(ARGV)