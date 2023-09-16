module RubyTube
  class Extractor
    class << self
      def playability_status(watch_html)
        player_response = initial_player_response(watch_html)
        player_response = JSON.parse(player_response)
        status_obj = player_response['playabilityStatus'] || {}
      
        if status_obj.has_key?('liveStreamability')
          return ['LIVE_STREAM', 'Video is a live stream.']
        end
      
        if status_obj.has_key?('status')
          if status_obj.has_key?('reason')
            return [status_obj['status'], [status_obj['reason']]]
          end
      
          if status_obj.has_key?('messages')
            return [status_obj['status'], status_obj['messages']]
          end
        end
      
        [nil, [nil]]
      end

      def video_id(url)
        return Utils.regex_search(/(?:v=|\/)([0-9A-Za-z_-]{11}).*/, url, 1)
      end

      private

      def initial_player_response(watch_html)
        patterns = [
          "window\\[['\"]ytInitialPlayerResponse['\"]\\]\\s*=\\s*",
          "ytInitialPlayerResponse\\s*=\\s*"
        ]
      
        patterns.each do |pattern|
          begin
            return Parser.parse_for_object(watch_html, pattern)
          rescue HTMLParseError
            next
          end
        end
      
        raise RegexMatchError.new('initial_player_response', 'initial_player_response_pattern')
      end
    end
  end
end
