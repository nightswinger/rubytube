module RubyTube
  class Stream
    attr_accessor(
      :monostate,
      :url,
      :itag,
      :mime_type,
      :codecs,
      :type,
      :subtype,
      :file_size,
      :is_otf,
      :bitrate
    )

    def initialize(stream, monostate)
      self.monostate = monostate

      self.url = stream["url"]
      self.itag = stream["itag"].to_i

      self.mime_type, self.codecs = Extractor.mime_type_codec(stream["mimeType"])
      self.type, self.subtype = mime_type.split("/")

      self.is_otf = stream["is_otf"]
      self.bitrate = stream["bitrate"]

      self.file_size = stream.fetch("contentLength", 0).to_i
    end

    def download(filename: nil, output_dir: nil)
      file_path = get_file_path(filename, output_dir)

      return file_path if File.exist?(file_path)

      bytes_remaining = file_size

      File.open(file_path, "wb") do |f|
        Request.stream(url) do |chunk|
          bytes_remaining -= chunk.bytesize
          f.write(chunk)
        end
      rescue HTTPError => e
        raise e if e.code != 404
      end

      file_path
    end

    def is_audio?
      type == "audio"
    end

    def is_video?
      type == "video"
    end

    def is_adaptive?
      codecs.size % 2 == 1
    end

    def is_progressive?
      !is_adaptive?
    end

    def title
      monostate.title
    end

    def resolution
      stream_format.resolution
    end

    private

    def get_file_path(filename, output_dir, prefix = "")
      filename ||= default_filename

      if prefix
        filename = "#{prefix}#{filename}"
      end

      output_path = Utils.target_directory(output_dir)
      File.join(output_path, filename)
    end

    def default_filename
      "#{monostate.title}.#{subtype}"
    end

    def stream_format
      @stream_format ||= StreamFormat.new(itag)
    end
  end
end
