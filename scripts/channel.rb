# Live check of RubyTube::Channel against real YouTube.
#   ruby scripts/channel.rb "<channel url | UC... | @handle>" [count]
require_relative "../lib/rubytube"

ref = ARGV[0] or abort "usage: ruby scripts/channel.rb <channel url> [count]"
count = (ARGV[1] || 40).to_i # > 30 forces at least one browse continuation

channel = RubyTube::Channel.new(ref)
puts "#{channel.name} (#{channel.channel_id})"

videos = channel.videos.first(count)
videos.each_with_index do |v, i|
  puts format("%3d. %-11s %6s  %-14s %-16s %s", i + 1, v.video_id, v.length, v.view_count_text, v.published_text, v.title)
end

abort "NO VIDEOS" if videos.empty?
abort "DUPLICATE IDS" unless videos.map(&:video_id).uniq.size == videos.size
puts "#{videos.size} videos, OK"
