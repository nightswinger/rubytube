module RubyTube
  # One entry of a video listing (channel tab, playlist). Built from the listing only: no per-video request is made
  # until #to_youtube. view_count_text / published_text are YouTube's rounded English strings.
  VideoItem = Data.define(:video_id, :title, :length, :view_count_text, :published_text, :thumbnail_url) do
    def url = "https://www.youtube.com/watch?v=#{video_id}"
    def to_youtube = YouTube.new(video_id)

    def self.from_lockup(lockup)
      meta = lockup.dig("metadata", "lockupMetadataViewModel")
      # Usually one row ["16K views", "2 days ago"]; collaborations prepend a row of channel names.
      rows = Array(meta&.dig("metadata", "contentMetadataViewModel", "metadataRows"))
             .map { |r| Array(r["metadataParts"]).filter_map { |p| p.dig("text", "content") } }
      parts = rows.find { |r| r.any? { |t| t.include?("view") } } || rows.last || []
      views = parts.find { |t| t.include?("view") }
      badge = Array(lockup.dig("contentImage", "thumbnailViewModel", "overlays"))
              .flat_map { |o| Array(o.dig("thumbnailBottomOverlayViewModel", "badges")) }
              .filter_map { |b| b.dig("thumbnailBadgeViewModel", "text") }
              .find { |t| t.match?(/\A\d+(:\d\d)+\z/) }
      new(video_id: lockup.fetch("contentId"),
          title: meta&.dig("title", "content"),
          length: badge&.split(":")&.reduce(0) { |acc, n| acc * 60 + n.to_i },
          view_count_text: views,
          published_text: (parts - [views]).first,
          thumbnail_url: Array(lockup.dig("contentImage", "thumbnailViewModel", "image", "sources"))
                           .max_by { |s| s["width"].to_i }&.dig("url"))
    end
  end
end
