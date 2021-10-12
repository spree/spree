# frozen_string_literal: true

module Spree
  module Webhooks
    module Endpoints
      class MakeRequest
        def initialize(body:, url:)
          @body = body
          @url = url
        end

        def call
          return if body == ''

          Rails.logger.debug("[SPREE WEBHOOKS] #{object_class_name} #{event_name} sending to #{url}")
          Rails.logger.debug("[SPREE WEBHOOKS] body: #{body}")

          if unprocessable_uri?
            Rails.logger.warn(UNPROCESSABLE_MSG)
            return
          end

          if failed_request?
            Rails.logger.warn(FAIL_MSG)
            return
          end

          Rails.logger.debug(SUCCESS_MSG)
        end

        private

        attr_reader :body, :url

        FAIL_MSG = '[SPREE WEBHOOKS] #{object_class_name} #{event_name} failed for #{url}'
        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        SUCCESS_MSG = "[SPREE WEBHOOKS] #{object_class_name} #{event_name} success for URL #{url}"
        UNPROCESSABLE_MSG = 'Can not make a request to the given URL'
        private_constant :FAIL_MSG, :HEADERS, :SUCCESS_MSG, :UNPROCESSABLE_MSG

        delegate :host, :path, :port, to: :uri, prefix: true

        def unprocessable_uri?
          uri_path == '' && uri_host.nil? && uri_port.nil?
        end

        def failed_request?
          request_code_type != Net::HTTPOK
        end

        def request_code_type
          http = Net::HTTP.new(uri_host, uri_port)
          http.use_ssl = true unless Rails.env.development? || Rails.env.test?
          http.request(request).code_type
        end

        def request
          req = Net::HTTP::Post.new(uri_path, HEADERS)
          req.body = body
          req
        end

        def uri
          URI(url)
        end
      end
    end
  end
end
