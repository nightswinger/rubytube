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
      status, messages = Extractor.playability_status(watch_html)

      messages.each do |reason|
        case status
        when 'UNPLAYABLE'
          case reason
          when 'Join this channel to get access to members-only content like this video, and other exclusive perks.'
            raise MembersOnly.new(video_id)
          when 'This live stream recording is not available.'
            raise RecordingUnavailable.new(video_id)
          else
            raise VideoUnavailable.new(video_id)
          end
        when 'LOGIN_REQUIRED'
          if reason == 'This is a private video. Please sign in to verify that you may see it.'
            raise VideoPrivate.new(video_id)
          end
        when 'ERROR'
          if reason == 'Video unavailable'
            raise VideoUnavailable.new(video_id)
          end
        when 'LIVE_STREAM'
          raise LiveStreamError.new(video_id)
        end
      end
    end

    def vid_info
      return @vid_info if @vid_info

      it = InnerTube.new
      @vid_info = it.player(video_id)

      @vid_info
    end
  end
end
