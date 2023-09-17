module RubyTube
  class InnerTube
    DEFALUT_CLIENTS = {
      'WEB' => {
        context: {
          client: {
            clientName: 'WEB',
            clientVersion: '2.20200720.00.02'
          }
        },
        header: { 'User-Agent': 'Mozilla/5.0' },
        api_key: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
      },
      'ANDROID_MUSIC' => {
        context: {
          client: {
            clientName: 'ANDROID_MUSIC',
            clientVersion: '5.16.51',
            androidSdkVersion: 30,
          },
        },
        header: { 'User-Agent': 'com.google.android.apps.youtube.music/'},
        api_key: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
      }
    }

    BASE_URL = 'https://www.youtube.com/youtubei/v1'

    attr_accessor :context, :header, :api_key, :access_token, :refresh_token, :use_oauth, :allow_cache, :expires

    def initialize(client: 'ANDROID_MUSIC', use_oauth: false, allow_cache: false)
      self.context = DEFALUT_CLIENTS[client][:context]
      self.header  = DEFALUT_CLIENTS[client][:header]
      self.api_key = DEFALUT_CLIENTS[client][:api_key]
      self.use_oauth = use_oauth
      self.allow_cache = allow_cache
    end

    def cache_tokens
      return unless allow_cache

      # TODO:
    end

    def refresh_bearer_token(force: false)
      # TODO:
    end

    def fetch_bearer_token
      # TODO:
    end

    def send(endpoint, query, data)
      if use_oauth
        query.delete(:key)
      end

      headers = {
        'Content-Type': 'application/json',
      }

      if use_oauth
        if access_token
          refresh_bearer_token
          headers['Authorization'] = "Bearer #{access_token}"
        else
          fetch_bearer_token
          headers['Authorization'] = "Bearer #{access_token}"
        end
      end

      options = {}
      options[:headers] = headers.merge(header)

      options[:query] = {
        key: api_key,
        contentCheckOk: true,
        racyCheckOk: true,
      }.merge(query)
      options[:data] = data

      resp = Request.post(endpoint, options)
      JSON.parse(resp)
    end

    def player(video_id)
      endpoint = "#{BASE_URL}/player"
      query = { 'videoId' => video_id }

      send(endpoint, query, {context: context})
    end
  end
end
