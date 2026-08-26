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
        formats = Array(streaming_data["adaptiveFormats"]).select { |f| f["url"] }
        StreamQuery.new(formats.map { |f| Stream.new(f, self) })
      end
    end

    def download(output_path: nil, filename: nil, container: "mp4", max_resolution: nil,
                 audio_only: false, skip_existing: true, max_retries: 0, &progress)
      audio = streams.best_audio(container:) or raise ExtractError, "no #{container} audio stream for #{video_id}"
      return audio.download(output_path:, filename:, skip_existing:, max_retries:, &progress) if audio_only

      video = streams.best_video(container:, max_resolution:) or
        raise ExtractError, "no #{container} video stream for #{video_id}"
      target = File.join(File.expand_path(output_path || Dir.pwd), filename || video.default_filename)
      return target if skip_existing && File.size?(target)

      remaining = video.filesize + audio.filesize
      track = lambda do |chunk, _|
        remaining -= chunk.bytesize
        progress&.call(chunk, remaining)
      end
      parts = [video, audio].map do |s|
        s.download(output_path: File.dirname(target), filename: "#{File.basename(target)}.#{s.itag}.part",
                   skip_existing: false, max_retries:, &track)
      end
      mux(parts, target)
      target
    ensure
      parts&.each { |part| File.delete(part) if File.exist?(part) }
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

    def mux(inputs, target)
      ok = system("ffmpeg", "-y", "-loglevel", "error", *inputs.flat_map { |i| ["-i", i] }, "-c", "copy", target)
      return if ok

      File.delete(target) if File.exist?(target)
      raise Error, ok.nil? ? "ffmpeg not found: install it, or fetch tracks separately via streams.best_video / best_audio" :
                             "ffmpeg failed to mux #{target}"
    end

    def check_availability(data)
      status = data.dig("playabilityStatus", "status")
      return if status == "OK"

      reason = data.dig("playabilityStatus", "reason") || "unknown reason"
      raise VideoUnavailable.new(status || "NO_STATUS", reason)
    end
  end
end
