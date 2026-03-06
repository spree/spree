# frozen_string_literal: true

require 'ssrf_filter'
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
        SsrfFilter.post(
          @delivery.url,
          headers: {
            'Content-Type' => 'application/json',
            'User-Agent' => 'Spree-Webhooks/1.0',
            'X-Spree-Webhook-Signature' => generate_signature,
            'X-Spree-Webhook-Event' => @delivery.event_name
          },
          body: @delivery.payload.to_json,
          http_options: {
            open_timeout: TIMEOUT,
            read_timeout: TIMEOUT,
            verify_mode: ssl_verify_mode
          }
        )
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
