module RubyTube
  class Playlist
    PLAYLIST_ID_PATTERNS = [
      /[?&]list=([0-9A-Za-z_-]+)/,
      /\A((?:PL|UU|OLAK5uy_|RD|LL|FL|EC|UL|TL|PU)[0-9A-Za-z_-]{10,})\z/
    ].freeze

    attr_reader :playlist_id

    def initialize(url)
      @playlist_id = self.class.extract_playlist_id(url)
      @innertube = InnerTube.new
    end

    def self.extract_playlist_id(url)
      PLAYLIST_ID_PATTERNS.each do |pattern|
        match = pattern.match(url)
        return match[1] if match
      end
      raise ExtractError, "could not extract a playlist id from #{url.inspect}"
    end

    def url = "https://www.youtube.com/playlist?list=#{playlist_id}"
    def title = metadata["title"]
    def description = metadata["description"]
    def length = stats_text(/([\d,]+) videos?\b/)&.delete(",")&.to_i
    def views = stats_text(/([\d,]+) views?\b/)&.delete(",")&.to_i
    def last_updated_text = stats_text(/(?:Last updated on |Updated )(.+)/)
    def owner = owner_run&.dig("text")&.delete_prefix("by ")
    def owner_id = owner_run&.dig("navigationEndpoint", "browseEndpoint", "browseId")
    def channel = Channel.new(owner_id)

    def thumbnail_url
      thumbnails = sidebar_primary&.dig("thumbnailRenderer")&.values&.first&.dig("thumbnail", "thumbnails") ||
                   initial_data.dig("microformat", "microformatDataRenderer", "thumbnail", "thumbnails")
      Array(thumbnails).max_by { |t| t["width"].to_i }&.dig("url")
    end

    # Lazy: continuation pages are fetched only as far as you enumerate. Includes unavailable
    # (private/deleted) entries when YouTube lists them; VideoItem#to_youtube raises for those.
    def videos
      Enumerator.new do |y|
        items = first_page_items
        visitor_data = initial_data.dig("responseContext", "visitorData")
        seen = nil
        loop do
          token = nil
          items.each do |item|
            if (lockup = item["lockupViewModel"])
              y << VideoItem.from_lockup(lockup) if lockup["contentType"] == "LOCKUP_CONTENT_TYPE_VIDEO" && lockup["contentId"]
            else
              token = InnerTube.continuation_token(item)
            end
          end
          break if token.nil? || token == seen

          seen = token
          response = @innertube.browse(continuation: token, visitor_data:)
          items = Array(response.dig("onResponseReceivedActions", 0, "appendContinuationItemsAction", "continuationItems") ||
                        response.dig("onResponseReceivedEndpoints", 0, "appendContinuationItemsAction", "continuationItems"))
        end
      end.lazy
    end

    private

    # "wgYCCAA=" is the "show unavailable videos" browse param, so private/deleted entries are listed too.
    def initial_data
      @initial_data ||= @innertube.browse(browse_id: "VL#{playlist_id}", params: "wgYCCAA=").tap do |data|
        next if data["contents"]

        alert = Array(data["alerts"]).filter_map { |a| a.dig("alertRenderer", "text", "runs", 0, "text") }.first
        raise ExtractError, "playlist #{playlist_id}: #{alert || 'no contents in browse response'}"
      end
    end

    # Video lockups plus the continuation item, which YouTube puts either at the end of the item
    # section or as a sibling section.
    def first_page_items
      sections = initial_data.dig("contents", "twoColumnBrowseResultsRenderer", "tabs", 0, "tabRenderer", "content",
                                  "sectionListRenderer", "contents") or
        raise ExtractError, "no video list for playlist #{playlist_id}"
      sections.flat_map { |section| section.dig("itemSectionRenderer", "contents") || [section] }
    end

    def metadata = initial_data.dig("metadata", "playlistMetadataRenderer") || {}
    def sidebar_primary = initial_data.dig("sidebar", "playlistSidebarRenderer", "items", 0, "playlistSidebarPrimaryInfoRenderer")

    def header_rows
      Array(initial_data.dig("header", "pageHeaderRenderer", "content", "pageHeaderViewModel", "metadata",
                             "contentMetadataViewModel", "metadataRows")).flat_map { |row| Array(row["metadataParts"]) }
    end

    # Stats appear as text runs in the sidebar (old layout) and as metadata parts in the page header (new layout).
    def stats_text(pattern)
      texts = Array(sidebar_primary&.dig("stats")).map { |s| s["simpleText"] || Array(s["runs"]).map { |r| r["text"] }.join } +
              header_rows.filter_map { |part| part.dig("text", "content") }
      texts.each { |text| (match = pattern.match(text)) and return match[1] }
      nil
    end

    def owner_run
      initial_data.dig("sidebar", "playlistSidebarRenderer", "items", 1, "playlistSidebarSecondaryInfoRenderer",
                       "videoOwner", "videoOwnerRenderer", "title", "runs", 0) ||
        header_rows.filter_map { |part| part.dig("avatarStack", "avatarStackViewModel", "text") }.first&.then do |text|
          { "text" => text["content"],
            "navigationEndpoint" => text.dig("commandRuns", 0, "onTap", "innertubeCommand") }
        end
    end
  end
end
