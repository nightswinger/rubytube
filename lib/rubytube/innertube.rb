require "net/http"
require "json"
require "uri"

module RubyTube
  class InnerTube
    BASE = "https://www.youtube.com/youtubei/v1"

    CLIENT_VERSION = "1.02"
    CLIENT_ID = "101"
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 " \
                 "(KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    WEB_CLIENT_ID = "1"
    WEB_CLIENT_VERSION = "2.20260708.00.00"

    CLIENT_CONTEXT = {
      clientName: "VISIONOS",
      clientVersion: CLIENT_VERSION,
      deviceMake: "Apple",
      deviceModel: "RealityDevice17,1",
      osName: "visionOS",
      osVersion: "26.5.23O471",
      hl: "en",
      gl: "US"
    }.freeze

    WEB_CLIENT_CONTEXT = {
      clientName: "WEB",
      clientVersion: WEB_CLIENT_VERSION,
      hl: "en",
      gl: "US"
    }.freeze

    # Channel/playlist listing: first page by browse_id (+ params), later pages by continuation.
    # visitor_data (from the previous response) is optional but keeps pagination consistent.
    def browse(continuation: nil, browse_id: nil, params: nil, visitor_data: nil)
      client = visitor_data ? WEB_CLIENT_CONTEXT.merge(visitorData: visitor_data) : WEB_CLIENT_CONTEXT
      body = { context: { client: }, continuation:, browseId: browse_id, params: }.compact
      post("browse", body, client_id: WEB_CLIENT_ID, client_version: WEB_CLIENT_VERSION, visitor_data:)
    end

    # Continuation token of a listing item, or nil. YouTube has used three shapes for it.
    def self.continuation_token(item)
      endpoint = item.dig("continuationItemRenderer", "continuationEndpoint") ||
                 item.dig("continuationItemViewModel", "continuationCommand", "innertubeCommand") or return
      [endpoint, *endpoint.dig("commandExecutorCommand", "commands")]
        .filter_map { |command| command.dig("continuationCommand", "token") }.first
    end

    def player(video_id)
      post("player",
           { context: { client: CLIENT_CONTEXT.merge(visitorData: visitor_data) },
             videoId: video_id,
             contentCheckOk: true,
             racyCheckOk: true })
    end

    def visitor_data
      @visitor_data ||= post("visitor_id", { context: { client: CLIENT_CONTEXT } })
                        .dig("responseContext", "visitorData") or
        raise ExtractError, "could not obtain visitorData"
    end

    private

    def post(endpoint, payload, client_id: CLIENT_ID, client_version: CLIENT_VERSION, visitor_data: @visitor_data)
      uri = URI("#{BASE}/#{endpoint}?prettyPrint=false")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = USER_AGENT
      request["X-Youtube-Client-Name"] = client_id
      request["X-Youtube-Client-Version"] = client_version
      request["X-Goog-Visitor-Id"] = visitor_data if visitor_data
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      raise ExtractError, "innertube #{endpoint} returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
