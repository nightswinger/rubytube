# Live check of RubyTube::Playlist against real YouTube.
#   ruby scripts/playlist.rb "<playlist url | PL...>" [count]
require_relative "../lib/rubytube"

ref = ARGV[0] or abort "usage: ruby scripts/playlist.rb <playlist url> [count]"
count = (ARGV[1] || 120).to_i # > 100 forces at least one browse continuation

playlist = RubyTube::Playlist.new(ref)
puts "#{playlist.title} by #{playlist.owner} (#{playlist.owner_id})"
puts "#{playlist.length} videos, #{playlist.views} views, updated #{playlist.last_updated_text}"
puts playlist.description.to_s.lines.first
puts playlist.thumbnail_url

videos = playlist.videos.first(count)
videos.each_with_index do |v, i|
  puts format("%3d. %-11s %6s  %-14s %-16s %s", i + 1, v.video_id, v.length, v.view_count_text, v.published_text, v.title)
end

abort "NO VIDEOS" if videos.empty?
abort "DUPLICATE IDS" unless videos.map(&:video_id).uniq.size == videos.size
puts "#{videos.size} videos, OK"
