module RubyTube
  class Stream
    attr_accessor :monostate, :url, :itag, :mime_type

    def initialize(stream, monostate)
      self.monostate = monostate

      self.url = stream['url']
      self.itag = stream['itag'].to_i
    end
  end
end
