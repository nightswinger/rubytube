module RubyTube
  module Request
    module_function

    DEFAULT_RANGE_SIZE = 9437184

    def get(url, options = {})
      send(:get, url, options).body
    end

    def post(url, options = {})
      send(:post, url, options).body
    end

    def head(url, options = {})
      send(:head, url, options).headers
    end

    def stream(url, timeout: 60, max_retries: 0)
      file_size = DEFAULT_RANGE_SIZE
      downloaded = 0

      while downloaded < file_size
        stop_pos = [downloaded + DEFAULT_RANGE_SIZE, file_size].min - 1
        range_header = "bytes=#{downloaded}-#{stop_pos}"
        tries = 0

        while true
          begin
            if tries >= 1 + max_retries
              raise MaxRetriesExceeded
            end
            response = send(:get, "#{url}&range=#{downloaded}-#{stop_pos}")
            break
          rescue Faraday::TimeoutError
          rescue Faraday::ClientError => e
            raise e
          end
          tries += 1
        end

        if file_size == DEFAULT_RANGE_SIZE
          begin
            resp = send(:get, "#{url}&range=0-99999999999")
            content_range = resp.headers["Content-Length"]
            file_size = content_range.to_i
          rescue KeyError, IndexError, StandardError => e
          end
        end

        response.body.each_char do |chunk|
          downloaded += chunk.length
          yield chunk
        end
      end
    end

    def send(method, url, options = {})
      headers = {"Content-Type": "text/html"}
      options[:headers] && headers.merge!(options[:headers])

      connection = Faraday.new(url: url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      connection.send(method) do |req|
        req.headers = headers
        options[:query] && req.params = options[:query]
        options[:data] && req.body = JSON.dump(options[:data])
      end
    end
  end
end
