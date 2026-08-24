module RubyTube
  class StreamQuery
    include Enumerable

    def initialize(streams)
      @streams = streams
    end

    def each(&) = @streams.each(&)
    def size = @streams.size
    def [](index) = @streams[index]
    def last = @streams.last
    def empty? = @streams.empty?

    def filter(itag: nil, res: nil, fps: nil, mime_type: nil, type: nil, subtype: nil,
               abr: nil, only_audio: nil, only_video: nil, progressive: nil, adaptive: nil, &block)
      selected = @streams
      selected = selected.select { |s| s.itag == itag } if itag
      selected = selected.select { |s| s.resolution == res } if res
      selected = selected.select { |s| s.fps == fps } if fps
      selected = selected.select { |s| s.mime_type == mime_type } if mime_type
      selected = selected.select { |s| s.type == type } if type
      selected = selected.select { |s| s.subtype == subtype } if subtype
      selected = selected.select { |s| s.abr == abr } if abr
      selected = selected.select { |s| s.only_audio? == only_audio } unless only_audio.nil?
      selected = selected.select { |s| s.only_video? == only_video } unless only_video.nil?
      selected = selected.select { |s| s.progressive? == progressive } unless progressive.nil?
      selected = selected.select { |s| s.adaptive? == adaptive } unless adaptive.nil?
      selected = selected.select(&block) if block
      StreamQuery.new(selected)
    end

    def order_by(attribute)
      StreamQuery.new(
        @streams.reject { |s| s.public_send(attribute).nil? }
                .sort_by { |s| sort_key(s.public_send(attribute)) }
      )
    end

    def get_by_itag(itag) = @streams.find { |s| s.itag == itag }

    def get_highest_resolution
      filter(progressive: true).max_by { |s| s.resolution.to_i }
    end

    def get_lowest_resolution
      filter(progressive: true).min_by { |s| s.resolution.to_i }
    end

    def get_audio_only(subtype = "mp4")
      filter(only_audio: true, subtype: subtype).max_by { |s| s.bitrate || 0 }
    end

    def to_s = "#<RubyTube::StreamQuery #{@streams.size} streams>"
    alias inspect to_s

    private

    def sort_key(value) = value.is_a?(String) ? value[/\d+/].to_i : value
  end
end
