module SpreeStripe
  class Gateway < ::Spree::Gateway
    # Webhook signature verification and endpoint registration.
    #
    # Signing secrets live in the gateway's own preferences. Before 6.0 they were
    # rows in spree_stripe_webhook_keys joined to payment methods many-to-many;
    # with a payment method now owned by exactly one store there is a single
    # endpoint per gateway, so a preference carries the same data. Existing
    # secrets are carried over by `spree:upgrade:migrate_stripe_webhook_keys`.
    module Webhooks
      extend ActiveSupport::Concern

      SUPPORTED_EVENTS = %w[
        payment_intent.amount_capturable_updated
        payment_intent.payment_failed
        payment_intent.succeeded
        setup_intent.succeeded
      ].freeze

      WEBHOOK_EVENT_ACTIONS = {
        'payment_intent.succeeded' => :captured,
        'payment_intent.amount_capturable_updated' => :authorized,
        'payment_intent.payment_failed' => :failed
      }.freeze

      included do
        preference :webhook_signing_secret, :password
        preference :webhook_endpoint_id, :string

        after_commit :create_webhook_endpoint_async, on: %i[create update]
      end

      # Translates a Stripe event into the normalized shape core's webhook
      # controller and `Spree::Payments::HandleWebhook` consume. Everything
      # after this — idempotency, locking, payment creation, order completion —
      # belongs to core.
      #
      # @param raw_body [String]
      # @param headers [Hash]
      # @return [Hash, nil] nil for events this gateway does not act on
      # @raise [Spree::PaymentMethod::WebhookSignatureError]
      def parse_webhook_event(raw_body, headers)
        event = verify_webhook_signature(raw_body, headers)

        action = WEBHOOK_EVENT_ACTIONS[event.type]
        return nil unless action

        payment_session = Spree::PaymentSessions::Stripe.find_by(
          payment_method: self,
          external_id: event.data.object[:id]
        )
        return nil unless payment_session

        { action: action, payment_session: payment_session }
      end

      def create_webhook_endpoint
        SpreeStripe::CreateGatewayWebhooks.new.call(payment_method: self)
      end

      private

      def verify_webhook_signature(raw_body, headers)
        signature = headers['HTTP_STRIPE_SIGNATURE']

        webhook_signing_secrets.each do |secret|
          return Stripe::Webhook.construct_event(raw_body, signature, secret)
        rescue Stripe::SignatureVerificationError
          next
        end

        raise Spree::PaymentMethod::WebhookSignatureError, 'Invalid webhook signature'
      end

      # The ENV fallback supports local development against the Stripe CLI, whose
      # secret is not the one registered for this endpoint.
      def webhook_signing_secrets
        [preferred_webhook_signing_secret, ENV['STRIPE_SIGNING_SECRET']].select(&:present?)
      end

      # Also the loop guard: registration writes the secret back through
      # `update!`, which re-runs this callback. A stored secret means the
      # endpoint is already registered, so the second pass stops here.
      def create_webhook_endpoint_async
        return if preferred_webhook_signing_secret.present?

        SpreeStripe::CreateWebhookEndpointJob.perform_later(id)
      end
    end
  end
end
