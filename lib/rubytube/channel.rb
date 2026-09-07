module RubyTube
  # One entry of a channel's Videos tab. Built from the listing only: no per-video request is made
  # until #to_youtube. view_count_text / published_text are YouTube's rounded English strings.
  ChannelVideo = Data.define(:video_id, :title, :length, :view_count_text, :published_text, :thumbnail_url) do
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

  class Channel
    CHANNEL_PATTERNS = [
      %r{youtube\.com/channel/(UC[0-9A-Za-z_-]{22})},
      %r{youtube\.com/(@[^/?#\s]+)},
      /\A(UC[0-9A-Za-z_-]{22})\z/,
      %r{\A(@[^/?#\s]+)\z}
    ].freeze

    def initialize(url)
      @ref = self.class.extract_channel_ref(url)
      @innertube = InnerTube.new
    end

    # Returns "UC..." or "@handle" (handles are percent-decoded, so non-ASCII ones read as written).
    def self.extract_channel_ref(url)
      CHANNEL_PATTERNS.each do |pattern|
        match = pattern.match(url)
        return URI.decode_uri_component(match[1]) if match
      end
      raise ExtractError, "could not extract a channel id or handle from #{url.inspect}"
    end

    def channel_id = channel_metadata["externalId"]
    def name = channel_metadata["title"]

    # Lazy: continuation pages are fetched only as far as you enumerate.
    def videos
      Enumerator.new do |y|
        items = videos_tab.dig("content", "richGridRenderer", "contents") or
          raise ExtractError, "no video grid in Videos tab of #{@ref}"
        visitor_data = initial_data.dig("responseContext", "webResponseContextExtensionData", "ytConfigData", "visitorData")
        seen = nil
        loop do
          token = nil
          items.each do |item|
            if (lockup = item.dig("richItemRenderer", "content", "lockupViewModel"))
              y << ChannelVideo.from_lockup(lockup) if lockup["contentType"] == "LOCKUP_CONTENT_TYPE_VIDEO"
            else
              token = item.dig("continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token")
            end
          end
          break if token.nil? || token == seen

          seen = token
          items = Array(@innertube.browse(continuation: token, visitor_data:)
                                  .dig("onResponseReceivedActions", 0, "appendContinuationItemsAction", "continuationItems"))
        end
      end.lazy
    end

    private

    def page_url
      path = @ref.start_with?("@") ? "@#{URI.encode_uri_component(@ref[1..])}" : "channel/#{@ref}"
      URI("https://www.youtube.com/#{path}/videos")
    end

    def initial_data
      @initial_data ||= begin
        response = Net::HTTP.get_response(page_url, "User-Agent" => InnerTube::USER_AGENT,
                                                    "Accept-Language" => "en-US,en;q=0.9")
        raise ExtractError, "channel page for #{@ref} returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        match = response.body.match(%r{ytInitialData\s*=\s*(\{.*?\});</script>}m) or
          raise ExtractError, "no ytInitialData in channel page for #{@ref}"
        JSON.parse(match[1])
      end
    end

    def channel_metadata
      initial_data.dig("metadata", "channelMetadataRenderer") or
        raise ExtractError, "no channel metadata for #{@ref} (channel not found?)"
    end

    def videos_tab
      tabs = Array(initial_data.dig("contents", "twoColumnBrowseResultsRenderer", "tabs"))
      tabs.filter_map { |t| t["tabRenderer"] }.find { |t| t["selected"] } or
        raise ExtractError, "no Videos tab for #{@ref}"
    end
  end
end
