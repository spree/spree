module SpreeStripe
  # Registers the gateway's webhook endpoint with Stripe and stores the signing
  # secret on the payment method.
  class CreateGatewayWebhooks
    # @param payment_method [SpreeStripe::Gateway]
    # @return [Stripe::WebhookEndpoint, nil]
    def call(payment_method:, events: SpreeStripe::Gateway::Webhooks::SUPPORTED_EVENTS, connect: false)
      webhook_url = payment_method.webhook_url
      return if webhook_url.blank?

      api_options = { api_key: payment_method.preferred_secret_key }
      existing = find_webhook(Stripe::WebhookEndpoint.list({}, api_options)[:data], webhook_url, events)

      # Stripe only returns the signing secret when the endpoint is created, so a
      # pre-existing endpoint whose secret we do not hold has to be replaced.
      if existing.present? && payment_method.preferred_webhook_endpoint_id == existing[:id] &&
         payment_method.preferred_webhook_signing_secret.present?
        return existing
      end

      Stripe::WebhookEndpoint.delete(existing[:id], {}, api_options) if existing.present?

      create_webhook_endpoint(payment_method, webhook_url, events, connect, api_options)
    end

    private

    def find_webhook(webhooks_data, webhook_url, enabled_events)
      webhooks_data.find do |webhook|
        webhook[:url] == webhook_url && webhook[:enabled_events].sort == enabled_events.sort
      end
    end

    def create_webhook_endpoint(payment_method, webhook_url, events, connect, api_options)
      stripe_webhook = Stripe::WebhookEndpoint.create(
        { url: webhook_url, enabled_events: events, connect: connect },
        api_options
      )

      payment_method.update!(
        preferred_webhook_endpoint_id: stripe_webhook[:id],
        preferred_webhook_signing_secret: stripe_webhook[:secret]
      )

      stripe_webhook
    end
  end
end
