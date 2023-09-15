module RubyTube
  module Request
    module_function

    def get(url, options)
      send(:get, url, options)
    end

    def post(url, options)
      send(:post, url, options)
    end

    def send(method, url, options = {})
      headers = {
        'Content-Type': 'application/json',
      }
      options[:headers] && headers.merge!(options[:headers])

      connection = Faraday.new(url)
      response = connection.send(method) do |req|
        req.headers = headers
        options[:query] && req.params = options[:query] 
        options[:data] && req.body = JSON.dump(options[:data])
      end
      JSON.parse(response.body)
    end
  end
end
