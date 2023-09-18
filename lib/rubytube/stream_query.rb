module RubyTube
  class StreamQuery
    attr_reader :streams

    def initialize(fmt_streams)
      @streams = fmt_streams
    end

    def filter(file_extension: nil, only_audio: false, only_video: false)
      filters = []

      filters << ->(stream) { stream.subtype == file_extension } if file_extension
      filters << ->(stream) { stream.is_audio? } if only_audio
      filters << ->(stream) { stream.is_video? } if only_video

      r = streams
      filters.each do |f|
        r = r.select(&f)
      end

      r
    end

    def first
      streams.first
    end

    def get_by_itag(itag)
      streams.find { |s| s.itag == itag }
    end
  end
end
