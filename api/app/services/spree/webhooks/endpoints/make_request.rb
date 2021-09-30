module Spree
  module Webhooks
    module Endpoints
      class MakeRequest
        prepend Spree::ServiceModule::Base

        def call(url:)
          p url
          run :make_request
        end

        private

        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        private_constant :HEADERS

        def make_request(url:)
          uri = URI(url)
          if uri.path == '' && uri.host.nil? && uri.port.nil?
            failure(false)
          else
            request = Net::HTTP::Post.new(uri.path, HEADERS)
            request.body = { foo: :bar }.to_json
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            success(http.request(request))
          end
        end
      end
    end
  end
end
