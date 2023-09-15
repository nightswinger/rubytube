module RubyTube
  class Extractor
    class << self
      def playability_status(watch_html)
      end

      def video_id(url)
        return Utils.regex_search(/(?:v=|\/)([0-9A-Za-z_-]{11}).*/, url, 1)
      end
    end
  end
end
