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
      #
      # @return [Array<#call>] the mutable decorator list
      def self.header_decorators
        @header_decorators ||= []
      end

      # @param delivery [Spree::WebhookDelivery] the pending delivery to send
      # @param secret_key [String] endpoint secret used to sign the payload
      def initialize(delivery:, secret_key:)
        @delivery = delivery
        @secret_key = secret_key
      end

      # Sends the webhook and records the outcome on the delivery. Transport
      # failures are captured on the record rather than raised, so a broken
      # endpoint never breaks the caller.
      #
      # @return [Spree::WebhookDelivery] the completed delivery
      def call
        ActiveSupport::Notifications.instrument(
          'deliver.spree_webhooks',
          event_name: @delivery.event_name,
          url_host: url_host
        ) do |payload|
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          begin
            response = make_request

            payload[:response_code] = response.code.to_i
            @delivery.complete!(
              response_code: response.code.to_i,
              execution_time: elapsed_since(start_time),
              response_body: response.body.to_s.truncate(10_000)
            )
          # Refusals are deliberate, so they are recorded rather than reported.
          # A name that does not resolve may be a passing DNS outage and is
          # retried; an internal or malformed address never becomes allowed.
          rescue SsrfFilter::UnresolvedHostname => e
            record_failure(e, start_time, payload, error_type: refused_url? ? 'blocked' : 'connection_error')
          rescue SsrfFilter::Error, URI::InvalidURIError => e
            record_failure(e, start_time, payload, error_type: 'blocked')
          rescue Net::OpenTimeout, Net::ReadTimeout => e
            Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
            record_failure(e, start_time, payload, error_type: 'timeout')
          rescue StandardError => e
            Rails.error.report(e, context: { webhook_delivery_id: @delivery.id, url: @delivery.url })
            record_failure(e, start_time, payload, error_type: 'connection_error')
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
        # localhost / host.docker.internal (the storefront running on the host),
        # and for hosts the operator explicitly trusts
        # (Spree::Api::Config.webhooks_allowed_internal_hosts).
        if Rails.env.development? || Spree::WebhookEndpoint.allowed_internal_host?(@delivery.url)
          uri = URI.parse(@delivery.url)
          # No proxy, as SsrfFilter: an egress proxy from the environment would
          # carry this in-cluster (or localhost) request out of the network.
          http = Net::HTTP.new(uri.hostname, uri.port, nil)
          http.use_ssl = uri.scheme == 'https'
          http_options.each { |k, v| http.send(:"#{k}=", v) }

          request = Net::HTTP::Post.new(uri.request_uri)
          headers.each { |k, v| request[k] = v }
          request.body = body
          http.request(request)
        else
          # A redirect is recorded as the endpoint's answer, never followed:
          # following it would hand the request to an address nobody checked
          # when the endpoint was saved.
          SsrfFilter.post(@delivery.url, headers: headers, body: body, http_options: http_options,
                                         max_redirects: 0, allow_unfollowed_redirects: true)
        end
      end

      # SsrfFilter resolves neither `127.1` nor `metadata.google.internal`;
      # the endpoint's own URL rules tell those apart from a DNS outage, with
      # no second lookup of a name that just failed to resolve.
      def refused_url?
        Spree::WebhookEndpoint::REFUSED_URL_ERRORS.include?(@delivery.webhook_endpoint.url_error(resolve: false))
      end

      def record_failure(error, start_time, payload, error_type:)
        payload[:error_type] = error_type
        @delivery.complete!(execution_time: elapsed_since(start_time), error_type: error_type, request_errors: error.message)
      end

      def elapsed_since(start_time)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
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
