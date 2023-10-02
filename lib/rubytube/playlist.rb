module RubyTube
  class Playlist < Array

    def initialize(input_url)
      @input_url = input_url
    end

    def id
      @id ||= Extractor.playlist_id(@input_url)
    end

    def url
      "https://www.youtube.com/playlist?list=#{id}"
    end

    private

    def extract_videos
      section_contents = initial_data.dig(
        "contents",
        "twoColumnBrowseResultsRenderer",
        "tabs", 0,
        "tabRenderer",
        "content",
        "sectionListRenderer",
        "contents"
      ) || {}
      important_content = section_contents.dig(
        0,
        "itemSectionRenderer",
        "contents", 0, 
        "playlistVideoListRenderer"
      ) || {}
      video_content = important_content["contents"]

      # video_content[0]['playlistVideoRenderer']['videoId']

      continuation = video_content.dig(
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
  end
end
