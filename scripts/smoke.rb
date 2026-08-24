require_relative "../lib/rubytube"
require "tmpdir"

url = ARGV[0] || "https://www.youtube.com/watch?v=jNQXAC9IVRw"
out = ARGV[1] || Dir.tmpdir

yt = RubyTube::YouTube.new(url)
puts "#{yt.title} (#{yt.length}s) by #{yt.author} — #{yt.views} views"

yt.streams.each { |s| puts "  #{s}" }

stream = yt.streams.get_audio_only || yt.streams.get_lowest_resolution || yt.streams.first
abort "no downloadable stream" unless stream
puts "downloading: #{stream}"

path = stream.download(output_path: out, skip_existing: false) do |_chunk, remaining|
  print "\r  #{remaining} bytes remaining      "
end
puts "\nsaved: #{path} (#{File.size(path)} bytes, expected #{stream.filesize})"
abort "SIZE MISMATCH" unless File.size(path) == stream.filesize
puts "OK"
