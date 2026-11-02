module SpreePaypalCheckout
  class Gateway < ::Spree::Gateway
    # Webhook signature verification and registration. Webhooks only report
    # money that has moved: the storefront completes the session as soon as the
    # buyer approves, so the approval itself is not subscribed to.
    module Webhooks
      extend ActiveSupport::Concern

      WEBHOOK_EVENT_ACTIONS = {
        'PAYMENT.CAPTURE.COMPLETED' => :captured,
        'PAYMENT.CAPTURE.PENDING' => :authorized,
        'PAYMENT.AUTHORIZATION.CREATED' => :authorized,
        'PAYMENT.CAPTURE.DENIED' => :failed,
        'PAYMENT.CAPTURE.DECLINED' => :failed
      }.freeze

      # Registration subscribes to exactly the events with a handler.
      SUPPORTED_EVENTS = WEBHOOK_EVENT_ACTIONS.keys.freeze

      # Where PayPal puts each value the verification call needs.
      SIGNATURE_HEADERS = {
        auth_algo: 'HTTP_PAYPAL_AUTH_ALGO',
        cert_url: 'HTTP_PAYPAL_CERT_URL',
        transmission_id: 'HTTP_PAYPAL_TRANSMISSION_ID',
        transmission_sig: 'HTTP_PAYPAL_TRANSMISSION_SIG',
        transmission_time: 'HTTP_PAYPAL_TRANSMISSION_TIME'
      }.freeze

      included do
        after_commit :register_webhook_async, on: %i[create update]
      end

      # Translates a PayPal event into the shape core's webhook handler takes.
      # Everything after this (idempotency, locking, payment creation, order
      # completion) belongs to core.
      #
      # @param raw_body [String]
      # @param headers [Hash, ActionDispatch::Http::Headers]
      # @return [Hash, nil] nil for events this gateway does not act on
      # @raise [Spree::PaymentMethod::WebhookSignatureError]
      def parse_webhook_event(raw_body, headers)
        event = verify_webhook_signature(raw_body, headers)

        action = WEBHOOK_EVENT_ACTIONS[event['event_type']]
        return nil unless action

        paypal_order_id = event.dig('resource', 'supplementary_data', 'related_ids', 'order_id')
        return nil if paypal_order_id.blank?

        payment_session = Spree::PaymentSessions::PaypalCheckout.find_by(payment_method: self, external_id: paypal_order_id)
        return nil unless payment_session

        { action: action, payment_session: payment_session }
      end

      def register_webhook
        SpreePaypalCheckout::RegisterWebhook.new.call(payment_method: self)
      end

      # @return [SpreePaypalCheckout::NotificationsClient]
      def notifications_client
        SpreePaypalCheckout::NotificationsClient.new(self)
      end

      private

      # Every delivery is checked with PayPal, in every environment. Anything
      # short of PayPal's SUCCESS is a rejected webhook, which PayPal delivers
      # again later.
      def verify_webhook_signature(raw_body, headers)
        if preferred_webhook_id.blank?
          raise Spree::PaymentMethod::WebhookSignatureError, 'PayPal webhook is not registered for this payment method'
        end

        event = parse_event(raw_body)
        signature = SIGNATURE_HEADERS.transform_values { |key| headers[key] }
        raise Spree::PaymentMethod::WebhookSignatureError, 'Missing PayPal signature headers' if signature.values.any?(&:blank?)

        verdict = notifications_client.verify_webhook_signature(
          raw_body: raw_body, headers: signature, webhook_id: preferred_webhook_id
        )
        raise Spree::PaymentMethod::WebhookSignatureError, 'Invalid webhook signature' unless verdict == 'SUCCESS'

        event
      rescue SpreePaypalCheckout::NotificationsClient::Error, *SpreePaypalCheckout::NotificationsClient::NETWORK_ERRORS,
             PaypalServerSdk::APIException, CoreLibrary::AuthValidationException, Faraday::Error, JSON::ParserError => e
        raise Spree::PaymentMethod::WebhookSignatureError, "PayPal could not verify the webhook: #{e.message}"
      end

      def parse_event(raw_body)
        event = JSON.parse(raw_body.to_s)
        raise Spree::PaymentMethod::WebhookSignatureError, 'Malformed webhook payload' unless event.is_a?(Hash)

        event
      rescue JSON::ParserError
        raise Spree::PaymentMethod::WebhookSignatureError, 'Malformed webhook payload'
      end

      # Registered when the method is created and whenever the credentials
      # change, since a webhook belongs to the REST app they name. Not when
      # registration itself stores the webhook id.
      def register_webhook_async
        return unless previously_new_record? ||
                      saved_change_to_preferred_client_id? ||
                      saved_change_to_preferred_client_secret? ||
                      saved_change_to_preferred_test_mode?

        SpreePaypalCheckout::RegisterWebhookJob.perform_later(id)
      end
    end
  end
end
