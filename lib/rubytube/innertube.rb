require "net/http"
require "json"
require "uri"

module RubyTube
  class InnerTube
    BASE = "https://www.youtube.com/youtubei/v1"

    CLIENT_VERSION = "1.65.10"
    CLIENT_ID = "28"
    USER_AGENT = "com.google.android.apps.youtube.vr.oculus/#{CLIENT_VERSION} " \
                 "(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"

    CLIENT_CONTEXT = {
      clientName: "ANDROID_VR",
      clientVersion: CLIENT_VERSION,
      deviceMake: "Oculus",
      deviceModel: "Quest 3",
      androidSdkVersion: 32,
      osName: "Android",
      osVersion: "12L",
      hl: "en",
      gl: "US"
    }.freeze

    def player(video_id)
      post("player",
           context: { client: CLIENT_CONTEXT.merge(visitorData: visitor_data) },
           videoId: video_id,
           contentCheckOk: true,
           racyCheckOk: true)
    end

    def visitor_data
      @visitor_data ||= post("visitor_id", context: { client: CLIENT_CONTEXT })
                        .dig("responseContext", "visitorData") or
        raise ExtractError, "could not obtain visitorData"
    end

    private

    def post(endpoint, payload)
      uri = URI("#{BASE}/#{endpoint}?prettyPrint=false")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = USER_AGENT
      request["X-Youtube-Client-Name"] = CLIENT_ID
      request["X-Youtube-Client-Version"] = CLIENT_VERSION
      request["X-Goog-Visitor-Id"] = @visitor_data if @visitor_data
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      raise ExtractError, "innertube #{endpoint} returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
