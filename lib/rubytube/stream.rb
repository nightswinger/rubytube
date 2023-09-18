module RubyTube
  class Stream
    attr_accessor :monostate, :url, :itag, :mime_type, :codecs, :type, :subtype, :file_size

    def initialize(stream, monostate)
      self.monostate = monostate

      self.url = stream['url']
      self.itag = stream['itag'].to_i

      self.mime_type, self.codecs = Extractor.mime_type_codec(stream['mimeType'])
      self.type, self.subtype = mime_type.split('/')

      self.file_size = stream.fetch('contentLength', 0).to_i
    end

    def download(filename: nil, output_dir: nil)
      file_path = get_file_path(filename, output_dir)

      bytes_remaining = file_size

      File.open(file_path, 'wb') do |f|
        begin
          Request.stream(url) do |chunk|
            bytes_remaining -= chunk.bytesize
            f.write(chunk)
          end
        rescue HTTPError => e
          raise e if e.code != 404
        end
      end

      file_path
    end

    def is_audio?
      type == 'audio'
    end

    def is_video?
      type == 'video'
    end

    private

    def get_file_path(filename, output_dir, prefix = '')
      filename = default_filename unless filename

      if prefix
        filename = "#{prefix}#{filename}"
      end

      output_path = Utils.target_directory(output_dir)
      File.join(output_path, filename)
    end

    def default_filename
      "#{monostate.title}.#{subtype}"
    end
  end
end
