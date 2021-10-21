# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class MakeRequest
        def initialize(body:, url:)
          @body = body
          @url = url
          @webhooks_timeout = ENV['SPREE_WEBHOOKS_TIMEOUT']
        end

        def failed_request?
          (200...300).exclude?(request_status_code)
        end

        def unprocessable_uri?
          uri_path == '' && uri_host.nil? && uri_port.nil?
        end

        private

        attr_reader :body, :url, :webhooks_timeout

        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        private_constant :HEADERS

        delegate :host, :path, :port, to: :uri, prefix: true

        def request_status_code
          http.request(request).code.to_i
        rescue Errno::ECONNREFUSED, Net::ReadTimeout, SocketError
          0
        end

        def http
          http = Net::HTTP.new(uri_host, uri_port)
          http.read_timeout = webhooks_timeout.to_i if custom_read_timeout?
          http.use_ssl = true if use_ssl?
          http
        end

        def request
          req = Net::HTTP::Post.new(uri_path, HEADERS)
          req.body = body
          req
        end

        def custom_read_timeout?
          webhooks_timeout.present?
        end

        def use_ssl?
          !(Rails.env.development? || Rails.env.test?)
        end

        def uri
          URI(url)
        end
      end
    end
  end
end
