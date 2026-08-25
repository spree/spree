module SpreeStripe
  # Registers a webhook endpoint with Stripe and stores the signing secret on
  # the payment method.
  #
  # A marketplace registers two: one for its own payment events, one for the
  # events originating inside its sellers' connected accounts. Stripe scopes
  # those separately and signs each with its own secret, so which endpoint is
  # being registered decides the URL, the events, and the preference the secret
  # lands in.
  class CreateGatewayWebhooks
    # @param payment_method [SpreeStripe::Gateway]
    # @param connect [Boolean] true registers the connected-accounts endpoint
    # @return [Stripe::WebhookEndpoint, nil]
    def call(payment_method:, events: nil, connect: false)
      events ||= connect ? SpreeStripe::Gateway::Connect::CONNECT_EVENTS : SpreeStripe::Gateway::Webhooks::SUPPORTED_EVENTS
      webhook_url = connect ? payment_method.connect_webhook_url : payment_method.webhook_url
      return if webhook_url.blank?

      api_options = { api_key: payment_method.preferred_secret_key }
      # Asked for in full rather than taking Stripe's default page of ten: an
      # account holds at most sixteen endpoints, so one call sees them all, and
      # a marketplace registers two per gateway. Missing our own is not a
      # harmless miss — Stripe does not treat the URL as unique, so the caller
      # would create a second endpoint beside it and every event would arrive
      # twice, half of them signed with a secret we do not hold.
      existing = find_webhook(
        Stripe::WebhookEndpoint.list({ limit: 100 }, api_options)[:data],
        webhook_url,
        events
      )

      # Stripe only returns the signing secret when the endpoint is created, so a
      # pre-existing endpoint whose secret we do not hold has to be replaced.
      if existing.present? && stored_endpoint_id(payment_method, connect) == existing[:id] &&
         stored_secret(payment_method, connect).present?
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

    def stored_endpoint_id(payment_method, connect)
      connect ? payment_method.preferred_connect_webhook_endpoint_id : payment_method.preferred_webhook_endpoint_id
    end

    def stored_secret(payment_method, connect)
      if connect
        payment_method.preferred_connect_webhook_signing_secret
      else
        payment_method.preferred_webhook_signing_secret
      end
    end

    def create_webhook_endpoint(payment_method, webhook_url, events, connect, api_options)
      stripe_webhook = Stripe::WebhookEndpoint.create(
        { url: webhook_url, enabled_events: events, connect: connect },
        api_options
      )

      prefix = connect ? 'preferred_connect_webhook' : 'preferred_webhook'
      payment_method.update!(
        :"#{prefix}_endpoint_id" => stripe_webhook[:id],
        :"#{prefix}_signing_secret" => stripe_webhook[:secret]
      )

      stripe_webhook
    end
  end
end
