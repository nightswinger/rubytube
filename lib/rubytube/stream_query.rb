module RubyTube
  class StreamQuery
    attr_reader :streams

    def initialize(fmt_streams)
      @streams = fmt_streams
    end

    def first
      streams.first
    end
  end
end
