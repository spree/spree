module Spree
  module Webhooks
    module Endpoints
      class MakeRequest
        prepend Spree::ServiceModule::Base

        # rubocop:disable Lint/UnusedMethodArgument
        def call(body:, url:)
          return failure(false) if body == ''

          run :make_request
        end
        # rubocop:enable Lint/UnusedMethodArgument

        private

        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        private_constant :HEADERS

        def make_request(body:, url:)
          uri = URI(url)
          if uri.path == '' && uri.host.nil? && uri.port.nil?
            failure(false)
          else
            request = Net::HTTP::Post.new(uri.path, HEADERS)
            request.body = body
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true unless Rails.env.development? || Rails.env.test?
            code_type = http.request(request).code_type
            success(code_type == Net::HTTPOK)
          end
        end
      end
    end
  end
end
