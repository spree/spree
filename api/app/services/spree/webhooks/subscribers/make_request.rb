# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class MakeRequest
        def initialize(url:, webhook_payload_body:)
          @execution_time_in_milliseconds = 0
          @url = url
          @webhook_payload_body = webhook_payload_body
          @webhooks_timeout = ENV['SPREE_WEBHOOKS_TIMEOUT']
        end

        def execution_time
          request
          @execution_time_in_milliseconds
        end

        def failed_request?
          (200...300).exclude?(response_code)
        end

        def response_code
          request.code.to_i
        end

        def success?
          !unprocessable_uri? && !failed_request?
        end

        def unprocessable_uri?
          uri_path == '' && uri_host.nil? && uri_port.nil?
        end

        private

        attr_reader :execution_time_in_milliseconds, :url, :webhook_payload_body, :webhooks_timeout

        HEADERS = { 'Content-Type' => 'application/json' }.freeze
        private_constant :HEADERS

        delegate :host, :path, :port, to: :uri, prefix: true

        def http
          http = Net::HTTP.new(uri_host, uri_port)
          http.read_timeout = webhooks_timeout.to_i if custom_read_timeout?
          http.use_ssl = true if use_ssl?
          http
        end

        def request
          req = Net::HTTP::Post.new(uri_path, HEADERS)
          req.body = webhook_payload_body
          @request ||= begin
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            request_result = http.request(req)
            @execution_time_in_milliseconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).in_milliseconds
            request_result
          end
        rescue Errno::ECONNREFUSED, Net::ReadTimeout, SocketError
          Class.new do
            def self.code
              '0'
            end
          end
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
