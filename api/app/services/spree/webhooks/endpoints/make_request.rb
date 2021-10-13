# frozen_string_literal: true

module Spree
  module Webhooks
    module Endpoints
      class MakeRequest
        def initialize(body:, event:, url:)
          @body = body
          @event = event
          @url = url
        end

        def call
          return if body == ''

          Rails.logger.debug(webhooks_log("sending to '#{url}'"))
          Rails.logger.debug(webhooks_log("body: #{body}"))

          if unprocessable_uri?
            Rails.logger.warn(webhooks_log("can not make a request to '#{url}'"))
            return
          end

          if failed_request?
            Rails.logger.warn(webhooks_log("failed for '#{url}'"))
            return
          end

          Rails.logger.debug(webhooks_log("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event, :url

        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        private_constant :HEADERS

        delegate :host, :path, :port, to: :uri, prefix: true

        def unprocessable_uri?
          uri_path == '' && uri_host.nil? && uri_port.nil?
        end

        def failed_request?
          (200...300).exclude?(request_status_code)
        end

        def request_status_code
          http.request(request).code.to_i
        rescue SocketError, Net::ReadTimeout
          0
        end

        def http
          http = Net::HTTP.new(uri_host, uri_port)
          if (webhooks_timeout = ENV['SPREE_WEBHOOKS_TIMEOUT'])
            http.read_timeout = webhooks_timeout.to_i
          end
          unless Rails.env.development? || Rails.env.test?
            http.use_ssl = true 
          end
          http
        end

        def request
          req = Net::HTTP::Post.new(uri_path, HEADERS)
          req.body = body
          req
        end

        def uri
          URI(url)
        end

        def webhooks_log(msg)
          "[SPREE WEBHOOKS] '#{event}' #{msg}"
        end
      end
    end
  end
end
