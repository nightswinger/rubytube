module RubyTube
  class YouTube
    VIDEO_ID_PATTERNS = [
      %r{youtu\.be/([0-9A-Za-z_-]{11})},
      %r{youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/)([0-9A-Za-z_-]{11})},
      /\A([0-9A-Za-z_-]{11})\z/
    ].freeze

    attr_reader :video_id

    def initialize(url)
      @video_id = self.class.extract_video_id(url)
      @innertube = InnerTube.new
    end

    def self.extract_video_id(url)
      VIDEO_ID_PATTERNS.each do |pattern|
        match = pattern.match(url)
        return match[1] if match
      end
      raise ExtractError, "could not extract a video id from #{url.inspect}"
    end

    def player_response
      @player_response ||= @innertube.player(video_id).tap { |data| check_availability(data) }
    end

    def streams
      @streams ||= begin
        streaming_data = player_response["streamingData"] or
          raise ExtractError, "no streamingData in player response (live stream?)"
        formats = Array(streaming_data["formats"]) + Array(streaming_data["adaptiveFormats"])
        StreamQuery.new(formats.select { |f| f["url"] }.map { |f| Stream.new(f, self) })
      end
    end

    def video_details = player_response.fetch("videoDetails", {})
    def title = video_details["title"]
    def author = video_details["author"]
    def channel_id = video_details["channelId"]
    def length = video_details["lengthSeconds"]&.to_i
    def views = video_details["viewCount"]&.to_i
    def description = video_details["shortDescription"]
    def keywords = video_details["keywords"] || []

    def thumbnail_url
      video_details.dig("thumbnail", "thumbnails")&.max_by { |t| t["width"].to_i }&.dig("url")
    end

    private

    def check_availability(data)
      status = data.dig("playabilityStatus", "status")
      return if status == "OK"

      reason = data.dig("playabilityStatus", "reason") || "unknown reason"
      raise VideoUnavailable.new(status || "NO_STATUS", reason)
    end
  end
end
