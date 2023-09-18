module RubyTube
  class Client
    attr_accessor :video_id, :watch_url, :embed_url, :stream_monostate

    def initialize(url)
      self.video_id = Extractor.video_id(url)

      self.watch_url = "https://youtube.com/watch?v=#{video_id}"
      self.embed_url = "https://www.youtube.com/embed/#{video_id}"

      self.stream_monostate = Monostate.new
    end

    def watch_html
      return @watch_html if @watch_html

      @watch_html = Request.get(watch_url)
      @watch_html
    end

    def js
      return @js if @js

      @js = Request.get(js_url)
      @js
    end

    def js_url
      return @js_url if @js_url

      @js_url = Extractor.js_url(watch_html)
      @js_url
    end

    def streaming_data
      return vid_info['streamingData'] if vid_info && vid_info.key?('streamingData')
    end

    def fmt_streams
      check_availability
      return @fmt_streams if @fmt_streams

      @fmt_streams = []
      stream_manifest = Extractor.apply_descrambler(streaming_data)

      begin
        Extractor.apply_signature(stream_manifest, vid_info, js)
      rescue ExtractError
        js = nil
        js_url = nil
        Extractor.apply_signature(stream_manifest, vid_info, js)
      end

      for stream in stream_manifest
        @fmt_streams << Stream.new(stream, stream_monostate)
      end

      stream_monostate.title = title
      stream_monostate.duration = length

      @fmt_streams
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

    def streams
      return @streams if @streams

      check_availability
      @streams = StreamQuery.new(fmt_streams)
    end

    def vid_info
      return @vid_info if @vid_info

      it = InnerTube.new
      @vid_info = it.player(video_id)

      @vid_info
    end

    def title
      return @title if @title

      @title = vid_info['videoDetails']['title']
      @title
    end

    def length
      return @length if @length

      @length = vid_info['videoDetails']['lengthSeconds'].to_i
      @length
    end

    def views
      return @views if @views

      @views = vid_info['videoDetails']['viewCount'].to_i
      @views
    end
  end
end
