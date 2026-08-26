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

    def filter(itag: nil, res: nil, fps: nil, mime_type: nil, type: nil, container: nil, abr: nil, &block)
      selected = @streams
      selected = selected.select { |s| s.itag == itag } if itag
      selected = selected.select { |s| s.resolution == res } if res
      selected = selected.select { |s| s.fps == fps } if fps
      selected = selected.select { |s| s.mime_type == mime_type } if mime_type
      selected = selected.select { |s| s.type == type } if type
      selected = selected.select { |s| s.container == container } if container
      selected = selected.select { |s| s.abr == abr } if abr
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
    def video_streams = filter(type: "video")
    def audio_streams = filter(type: "audio")

    def best_video(container: "mp4", max_resolution: nil)
      candidates = video_streams.filter(container:)
      candidates = candidates.filter { |s| s.resolution.to_i <= max_resolution } if max_resolution
      candidates.max_by { |s| [s.resolution.to_i, s.fps.to_i, s.video_codec.start_with?("avc1") ? 1 : 0, s.bitrate.to_i] }
    end

    def best_audio(container: "mp4")
      audio_streams.filter(container:).max_by { |s| s.bitrate.to_i }
    end

    def to_s = "#<RubyTube::StreamQuery #{@streams.size} streams>"
    alias inspect to_s

    private

    def sort_key(value) = value.is_a?(String) ? value[/\d+/].to_i : value
  end
end
