# frozen_string_literal: true

require 'faraday'
require 'faraday/follow_redirects'

require_relative 'rubytube/version'

require_relative 'rubytube/cipher'
require_relative 'rubytube/client'
require_relative 'rubytube/extractor'
require_relative 'rubytube/innertube'
require_relative 'rubytube/monostate'
require_relative 'rubytube/parser'
require_relative 'rubytube/playlist'
require_relative 'rubytube/request'
require_relative 'rubytube/stream_format'
require_relative 'rubytube/stream_query'
require_relative 'rubytube/stream'
require_relative 'rubytube/utils'

module RubyTube
  class Error < StandardError; end
  class HTMLParseError < StandardError; end
  class ExtractError < StandardError; end
  class MaxRetriesExceeded < StandardError; end
  class VideoUnavailable < StandardError; end
  class InvalidArgumentError < ArgumentError; end

  class RegexMatchError < StandardError
    def initialize(caller, pattern)
      super("Regex match error in #{caller} for pattern #{pattern}")
    end
  end

  class MembersOnly < StandardError
    def initialize(video_id)
      super("Members only video: #{video_id}")
    end
  end
  
  class RecordingUnavailable < StandardError
    def initialize(video_id)
      super("Recording unavailable: #{video_id}")
    end
  end
  
  class VideoUnavailable < StandardError
    def initialize(video_id)
      super("Video unavailable: #{video_id}")
    end
  end
  
  class VideoPrivate < StandardError
    def initialize(video_id)
      super("Video is private: #{video_id}")
    end
  end
  
  class LiveStreamError < StandardError
    def initialize(video_id)
      super("Video is a live stream: #{video_id}")
    end
  end

  class << self
    def new(url)
      Client.new(url)
    end
  end
end
