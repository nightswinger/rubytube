require "net/http"
require "uri"
require "fileutils"

module RubyTube
  class Stream
    CHUNK_SIZE = 9 * 1024 * 1024

    attr_reader :itag, :url, :mime_type, :type, :subtype, :codecs, :bitrate,
                :fps, :width, :height, :resolution, :audio_sample_rate, :duration_ms

    def initialize(format, yt)
      @yt = yt
      @itag = format["itag"]
      @url = format["url"]
      @mime_type, @codecs = parse_mime_type(format["mimeType"])
      @type, @subtype = @mime_type.split("/")
      @bitrate = format["bitrate"]
      @fps = format["fps"]
      @width = format["width"]
      @height = format["height"]
      @resolution = format["qualityLabel"] || (@height && "#{@height}p")
      @audio_sample_rate = format["audioSampleRate"]&.to_i
      @duration_ms = format["approxDurationMs"]&.to_i
      @content_length = format["contentLength"]&.to_i&.nonzero?
      @otf = format["type"] == "FORMAT_STREAM_TYPE_OTF"
    end

    alias container subtype

    def video? = type == "video"
    def audio? = type == "audio"
    def otf? = @otf

    def video_codec = video? ? codecs.first : nil
    def audio_codec = audio? ? codecs.first : nil

    def abr = bitrate && "#{bitrate / 1000}kbps"

    def filesize
      @content_length ||= fetch_filesize
    end

    def default_filename
      name = (@yt.title || video_id_or_itag).gsub(%r{[/\\:*?"<>|]}, "").strip
      "#{name}.#{audio? && container == "mp4" ? "m4a" : container}"
    end

    def download(output_path: nil, filename: nil, filename_prefix: nil,
                 skip_existing: true, max_retries: 0)
      raise Error, "OTF streams are not supported" if otf?

      target = File.join(File.expand_path(output_path || Dir.pwd),
                         "#{filename_prefix}#{filename || default_filename}")
      return target if skip_existing && File.size?(target)

      FileUtils.mkdir_p(File.dirname(target))
      total = filesize
      downloaded = 0
      File.open(target, "wb") do |io|
        while downloaded < total
          chunk = fetch_range(downloaded, [downloaded + CHUNK_SIZE, total].min - 1, max_retries)
          io.write(chunk)
          downloaded += chunk.bytesize
          yield chunk, total - downloaded if block_given?
        end
      end
      target
    end

    def to_s
      attrs = { itag:, mime_type:, resolution:, fps:, abr: }.compact
      "#<RubyTube::Stream #{attrs.map { |k, v| "#{k}=#{v}" }.join(' ')}>"
    end
    alias inspect to_s

    private

    def video_id_or_itag = @yt.respond_to?(:video_id) ? @yt.video_id : itag.to_s

    def parse_mime_type(raw)
      match = raw&.match(%r{([\w-]+/[\w-]+);\s*codecs="([^"]+)"}) or
        raise ExtractError, "unparseable mimeType: #{raw.inspect}"
      [match[1], match[2].split(",").map(&:strip)]
    end

    def fetch_range(start, stop, max_retries)
      attempts = 0
      begin
        response = http.get(range_uri(start, stop), request_headers("bytes=#{start}-#{stop}"))
        raise Error, "HTTP #{response.code} while downloading itag #{itag}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      rescue Error, SystemCallError, IOError, Net::OpenTimeout, Net::ReadTimeout => e
        @http&.finish rescue nil
        @http = nil
        attempts += 1
        retry if attempts <= max_retries
        raise e
      end
    end

    def fetch_filesize
      response = http.get(range_uri(0, 0), request_headers("bytes=0-0"))
      total = response["Content-Range"]&.split("/")&.last&.to_i
      raise ExtractError, "cannot determine filesize for itag #{itag} (HTTP #{response.code})" unless total&.positive?

      total
    end

    def range_uri(start, stop)
      uri = URI(url)
      uri.query = [uri.query, "range=#{start}-#{stop}"].compact.join("&")
      uri.request_uri
    end

    def request_headers(range)
      { "Range" => range, "User-Agent" => InnerTube::USER_AGENT }
    end

    def http
      @http ||= begin
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true)
      end
    end
  end
end
