require_relative "../lib/rubytube"
require "tmpdir"

url = ARGV[0] || "https://www.youtube.com/watch?v=jNQXAC9IVRw"
out = ARGV[1] || Dir.tmpdir

yt = RubyTube::YouTube.new(url)
puts "#{yt.title} (#{yt.length}s) by #{yt.author} — #{yt.views} views"
yt.streams.each { |s| puts "  #{s}" }

channel = yt.channel
recent = channel.videos.first(3)
puts "channel: #{channel.name} (#{channel.channel_id}), latest: #{recent.map(&:title).inspect}"
abort "NO CHANNEL VIDEOS" if recent.empty?

video = yt.streams.best_video
audio = yt.streams.best_audio
puts "best video: #{video}\nbest audio: #{audio}"

path = yt.download(output_path: out, skip_existing: false, max_resolution: 360) do |_chunk, remaining|
  print "\r  #{remaining} bytes remaining      "
end
puts "\nsaved: #{path} (#{File.size(path)} bytes)"
abort "EMPTY OUTPUT" unless File.size?(path)
abort "PART FILES LEFT" if Dir.glob("#{path}.*.part").any?

audio_path = yt.download(output_path: out, audio_only: true, skip_existing: false)
puts "saved: #{audio_path} (#{File.size(audio_path)} bytes, expected #{audio.filesize})"
abort "SIZE MISMATCH" unless File.size(audio_path) == audio.filesize
puts "OK"
