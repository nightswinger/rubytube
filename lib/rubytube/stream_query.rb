module RubyTube
  class StreamQuery < Array
    attr_reader :streams

    def initialize(fmt_streams)
      super
      @streams = fmt_streams
    end

    def filter(file_extension: nil, only_audio: false, only_video: false, resolution: nil)
      filters = []

      filters << ->(stream) { stream.subtype == file_extension } if file_extension
      filters << ->(stream) { stream.is_audio? } if only_audio
      filters << ->(stream) { stream.is_video? } if only_video
      filters << ->(stream) { stream.resolution == resolution } if resolution

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

    def get_by_resolution(resolution)
      streams.find { |s| s.resolution == resolution }
    end
  end
end
