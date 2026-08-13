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

      # Callables invoked with (headers, delivery) before every webhook POST —
      # merge into the hash to add outbound headers (e.g. W3C trace context
      # propagation). Registrations live on a reloadable class: register from
      # a `config.to_prepare` block so they survive code reloads.
      def self.header_decorators
        @header_decorators ||= []
      end

      def initialize(delivery:, secret_key:)
        @delivery = delivery
        @secret_key = secret_key
      end

      def call
        ActiveSupport::Notifications.instrument(
          'deliver.spree_webhooks',
          event_name: @delivery.event_name,
          url_host: url_host
        ) do |payload|
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          begin
            response = make_request
            execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

            payload[:response_code] = response.code.to_i
            @delivery.complete!(
              response_code: response.code.to_i,
              execution_time: execution_time,
              response_body: response.body.to_s.truncate(10_000)
            )
          rescue Net::OpenTimeout, Net::ReadTimeout => e
            execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
            Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
            payload[:error_type] = 'timeout'
            @delivery.complete!(
              execution_time: execution_time,
              error_type: 'timeout',
              request_errors: e.message
            )
          rescue StandardError => e
            execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
            Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
            payload[:error_type] = 'connection_error'
            @delivery.complete!(
              execution_time: execution_time,
              error_type: 'connection_error',
              request_errors: e.message
            )
          end
        end
      end

      private

      def make_request
        headers = {
          'Content-Type' => 'application/json',
          'User-Agent' => 'Spree-Webhooks/1.0',
          'X-Spree-Webhook-Signature' => generate_signature,
          'X-Spree-Webhook-Timestamp' => webhook_timestamp.to_s,
          'X-Spree-Webhook-Event' => @delivery.event_name
        }
        self.class.header_decorators.each { |decorator| decorator.call(headers, @delivery) }

        body = payload_json
        http_options = { open_timeout: TIMEOUT, read_timeout: TIMEOUT, verify_mode: ssl_verify_mode }

        # SSRF protection is disabled in development so webhooks can reach
        # localhost / host.docker.internal (the storefront running on the host).
        if Rails.env.development?
          uri = URI.parse(@delivery.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http_options.each { |k, v| http.send(:"#{k}=", v) }

          request = Net::HTTP::Post.new(uri.request_uri)
          headers.each { |k, v| request[k] = v }
          request.body = body
          http.request(request)
        else
          SsrfFilter.post(@delivery.url, headers: headers, body: body, http_options: http_options)
        end
      end

      def generate_signature
        OpenSSL::HMAC.hexdigest('SHA256', @secret_key, "#{webhook_timestamp}.#{payload_json}")
      end

      # Memoized so the signature is computed over exactly the bytes sent.
      def payload_json
        @payload_json ||= @delivery.deliverable_payload.to_json
      end

      def webhook_timestamp
        @webhook_timestamp ||= Time.current.to_i
      end

      def url_host
        URI.parse(@delivery.url).host
      rescue URI::InvalidURIError
        nil
      end

      def ssl_verify_mode
        if Spree::Api::Config.webhooks_verify_ssl
          OpenSSL::SSL::VERIFY_PEER
        else
          Rails.logger.warn('[Spree] Webhook SSL verification is disabled. This is not recommended for production environments.')
          OpenSSL::SSL::VERIFY_NONE
        end
      end
    end
  end
end
