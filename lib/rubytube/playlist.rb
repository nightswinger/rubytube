module RubyTube
  class Playlist < Array

    def initialize(input_url)
      @input_url = input_url
      super(videos)
    end

    def id
      @id ||= Extractor.playlist_id(@input_url)
    end

    def url
      "https://www.youtube.com/playlist?list=#{id}"
    end

    def title
      @title ||= sidebar_info.dig(0, "playlistSidebarPrimaryInfoRenderer", "title", "runs", 0, "text")
    end

    def description
      @description ||= sidebar_info.dig(0, "playlistSidebarPrimaryInfoRenderer", "description", "simpleText")
    end

    def length
      @length ||= sidebar_info.dig(0, "playlistSidebarPrimaryInfoRenderer", "stats", 0, "runs", 0, "text").to_i
    end

    def views
      @views ||= sidebar_info.dig(0, "playlistSidebarPrimaryInfoRenderer", "stats", 1, "simpleText").split[0].gsub(',', '').to_i
    end

    private

    def videos
      @videos ||= video_urls.map { |url| Client.new(url) }
    end

    def video_urls
      video_content.map { |video| "/watch?v=#{video.dig("playlistVideoRenderer", "videoId")}" }
    end

    def section_contents
      @section_contents ||= initial_data.dig(
        "contents",
        "twoColumnBrowseResultsRenderer",
        "tabs", 0,
        "tabRenderer",
        "content",
        "sectionListRenderer",
        "contents"
      ) || {}
    end

    def important_content
      @important_content ||= section_contents.dig(
        0,
        "itemSectionRenderer",
        "contents", 0,
        "playlistVideoListRenderer"
      ) || {}
    end

    def video_content
      @video_content ||= important_content["contents"] || []
    end

    def continuation
      @continuation ||= important_content.dig(
        'contents',
        -1,
        'continuationItemRenderer',
        'continuationEndpoint',
        'continuationCommand',
        'token'
      )
    end

    def html
      @html ||= Request.get(url)
    end

    def initial_data
      @initial_data ||= JSON.parse(Extractor.initial_data(html))
    end

    def sidebar_info
      @sidebar_info ||= initial_data.dig(
        "sidebar",
        "playlistSidebarRenderer",
        "items"
      ) || []
    end
  end
end
