module RubyTube
  class Client
    attr_accessor :video_id, :watch_url, :embed_url

    def initialize(url)
      self.video_id = Extractor.video_id(url)

      self.watch_url = "https://www.youtube.com/watch?v=#{video_id}"
      self.embed_url = "https://www.youtube.com/embed/#{video_id}"
    end

    def watch_html
      return @watch_html if @watch_html

      @watch_html = Request.get(watch_url)
      @watch_html
    end

    def streaming_data
      return vid_info['streamingData'] if vid_info && vid_info.key?('streamingData')
    end

    def check_availability
      # TODO:
    end

    def vid_info
      return @vid_info if @vid_info

      it = InnerTube.new
      @vid_info = it.player(video_id)

      @vid_info
    end
  end
end
