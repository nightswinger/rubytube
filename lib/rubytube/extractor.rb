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

      def playlist_id(url)
        parsed = URI.parse(url)
        params = CGI.parse(parsed.query || '')
        params['list']&.first
      end

      def js_url(html)
        begin
          base_js = get_ytplayer_config(html)['assets']['js']
        rescue RegexMatchError, NoMethodError
          base_js = get_ytplayer_js(html)
        end

        "https://youtube.com#{base_js}"
      end

      def mime_type_codec(mime_type_codec)
        pattern = %r{(\w+\/\w+)\;\scodecs=\"([a-zA-Z\-0-9.,\s]*)\"}
        results = mime_type_codec.match(pattern)
      
        raise RegexMatchError.new("mime_type_codec, pattern=#{pattern}") if results.nil?
      
        mime_type, codecs = results.captures
        [mime_type, codecs.split(",").map(&:strip)]
      end

      def get_ytplayer_js(html)
        js_url_patterns = [
          %r{(/s/player/[\w\d]+/[\w\d_/.]+/base\.js)},
        ]

        js_url_patterns.each do |pattern|
          function_match = html.match(pattern)
          if function_match
            return function_match[1]
          end
        end

        raise RegexMatchError.new('get_ytplayer_js', 'js_url_patterns')
      end

      def get_ytplayer_config(html)
        config_patterns = [
          /ytplayer\.config\s*=\s*/,
          /ytInitialPlayerResponse\s*=\s*/
        ]

        config_patterns.each do |pattern|
          begin
            return Parser.parse_for_object(html, pattern)
          rescue HTMLParseError => e
            next
          end
        end

        setconfig_patterns = [
          /yt\.setConfig\(.*['\"]PLAYER_CONFIG['\"]:\s*/
        ]

        setconfig_patterns.each do |pattern|
          begin
            return Parser.parse_for_object(html, pattern)
          rescue HTMLParseError => e
            next
          end
        end

        raise RegexMatchError.new('get_ytplayer_config', 'config_patterns, setconfig_patterns')
      end

      def apply_signature(stream_manifest, vid_info, js)
        cipher = Cipher.new(js)

        stream_manifest.each_with_index do |stream, i|
          begin
            url = stream['url']
          rescue NoMethodError
            live_stream = vid_info.fetch('playabilityStatus', {})['liveStreamability']
            if live_stream
              raise LiveStreamError.new('UNKNOWN')
            end
          end

          if url.include?("signature") || 
            (!stream.key?("s") && (url.include?("&sig=") || url.include?("&lsig=")))
            # For certain videos, YouTube will just provide them pre-signed, in
            # which case there's no real magic to download them and we can skip
            # the whole signature descrambling entirely.
            next
          end

          signature = cipher.get_signature(stream['s'])

          parsed_url = URI.parse(url)

          query_params = CGI.parse(parsed_url.query)
          query_params.transform_values!(&:first)
          query_params['sig'] = signature
          unless query_params.key?('ratebypass')
            initial_n = query_params['n'].split('')
            new_n = cipher.calculate_n(initial_n)
            query_params['n'] = new_n
          end

          url = "#{parsed_url.scheme}://#{parsed_url.host}#{parsed_url.path}?#{URI.encode_www_form(query_params)}"

          stream_manifest[i]["url"] = url
        end
      end

      def apply_descrambler(stream_data)
        return if stream_data.has_key?('url')

        # Merge formats and adaptiveFormats into a single array
        formats = []
        formats += stream_data['formats'] if stream_data.has_key?('formats')
        formats += stream_data['adaptiveFormats'] if stream_data.has_key?('adaptiveFormats')

        # Extract url and s from signatureCiphers as necessary
        formats.each do |data|
          unless data.has_key?('url')
            if data.has_key?('signatureCipher')
              cipher_url = URI.decode_www_form(data['signatureCipher']).to_h
              data['url'] = cipher_url['url']
              data['s'] = cipher_url['s']
            end
          end
          data['is_otf'] = data['type'] == 'FORMAT_STREAM_TYPE_OTF'
        end

        formats
      end

      def initial_data(watch_html)
        patterns = [
          %r"window\[['\"]ytInitialData['\"]\]\s*=\s*",
          %r"ytInitialData\s*=\s*"
        ]
      
        patterns.each do |pattern|
          begin
            return Parser.parse_for_object(watch_html, pattern)
          rescue HTMLParseError
            next
          end
        end
      
        raise RegexMatchError.new('initial_data', 'initial_data_pattern')
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
