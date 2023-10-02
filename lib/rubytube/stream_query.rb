module RubyTube
  class StreamQuery < Array
    attr_reader :streams

    def initialize(fmt_streams)
      super
      @streams = fmt_streams
    end

    def filter(file_extension: nil, only_audio: false, only_video: false, resolution: nil, progressive: false, adaptive: false)
      filters = []

      filters << ->(stream) { stream.subtype == file_extension } if file_extension
      filters << ->(stream) { stream.is_audio? } if only_audio
      filters << ->(stream) { stream.is_video? } if only_video
      filters << ->(stream) { stream.resolution == resolution } if resolution
      filters << ->(stream) { stream.is_progressive? } if progressive
      filters << ->(stream) { stream.is_adaptive? } if adaptive

      r = streams
      filters.each do |f|
        r = r.select(&f)
      end

      StreamQuery.new(r)
    end

    def get_by_itag(itag)
      streams.find { |s| s.itag == itag }
    end

    def get_by_resolution(resolution)
      streams.find { |s| s.resolution == resolution }
    end

    def get_highest_resolution
      order(resolution: :desc).first
    end

    def order(arg)
      case arg
      when Symbol
        field = arg
        dir = :asc
      when Hash
        field = arg.keys.first
        dir = arg[field] == :desc ? :desc : :asc
      end

      allowed_fields = [:file_size, :itag, :resolution]
      raise InvalidArgumentError unless allowed_fields.include? field

      r = streams
      r.sort! {|a, b| a.send(field).to_i <=> b.send(field).to_i }

      r.reverse! if dir == :desc

      StreamQuery.new(r)
    end
  end
end
