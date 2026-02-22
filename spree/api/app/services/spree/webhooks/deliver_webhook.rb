# frozen_string_literal: true

require 'net/http'
require 'openssl'

module Spree
  module Webhooks
    class DeliverWebhook
      TIMEOUT = 30

      def self.call(delivery:, secret_key:)
        new(delivery: delivery, secret_key: secret_key).call
      end

      def initialize(delivery:, secret_key:)
        @delivery = delivery
        @secret_key = secret_key
      end

      def call
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        response = make_request
        execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

        @delivery.complete!(
          response_code: response.code.to_i,
          execution_time: execution_time,
          response_body: response.body.to_s.truncate(10_000)
        )
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
        @delivery.complete!(
          execution_time: execution_time,
          error_type: 'timeout',
          request_errors: e.message
        )
      rescue StandardError => e
        execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
        @delivery.complete!(
          execution_time: execution_time,
          error_type: 'connection_error',
          request_errors: e.message
        )
      end

      private

      def make_request
        uri = URI.parse(@delivery.url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.verify_mode = ssl_verify_mode
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT

        request = Net::HTTP::Post.new(uri.request_uri)
        request['Content-Type'] = 'application/json'
        request['User-Agent'] = 'Spree-Webhooks/1.0'
        request['X-Spree-Webhook-Signature'] = generate_signature
        request['X-Spree-Webhook-Event'] = @delivery.event_name
        request.body = @delivery.payload.to_json

        http.request(request)
      end

      def generate_signature
        payload_json = @delivery.payload.to_json
        OpenSSL::HMAC.hexdigest('SHA256', @secret_key, payload_json)
      end

      def ssl_verify_mode
        if Spree::Api::Config.webhooks_verify_ssl
          OpenSSL::SSL::VERIFY_PEER
        else
          OpenSSL::SSL::VERIFY_NONE
        end
      end
    end
  end
end
