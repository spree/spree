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
          Rails.logger.debug('logging')
          if uri.path == '' && uri.host.nil? && uri.port.nil?
            Rails.logger.debug('webhook request finished with errors')
            failure(false)
          else
            if request_code_type(body, uri) == Net::HTTPOK
              Rails.logger.debug('webhook sent successfully')
              success(true)
            else
              Rails.logger.warn('webhook request finished with errors')
              success(false)
            end
          end
        end

        def request_code_type(body, uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if ssl?
          http.request(request(body, uri.path)).code_type
        end

        def request(body, uri_path)
          req = Net::HTTP::Post.new(uri_path, HEADERS)
          req.body = body
          req
        end

        def ssl?
          !(Rails.env.development? || Rails.env.test?)
        end
      end
    end
  end
end
