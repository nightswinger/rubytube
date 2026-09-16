module RubyTube
  VERSION = "1.2.0"

  class Error < StandardError; end

  class ExtractError < Error; end

  class VideoUnavailable < Error
    attr_reader :status, :reason

    def initialize(status, reason)
      @status = status
      @reason = reason
      super("#{status}: #{reason}")
    end
  end
end

require_relative "rubytube/innertube"
require_relative "rubytube/stream"
require_relative "rubytube/stream_query"
require_relative "rubytube/youtube"
require_relative "rubytube/video_item"
require_relative "rubytube/channel"
require_relative "rubytube/playlist"
