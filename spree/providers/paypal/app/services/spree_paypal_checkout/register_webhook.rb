module SpreePaypalCheckout
  # Finds or creates the PayPal webhook for a payment method's URL and stores
  # its id on the method. A webhook found for the URL has its events replaced
  # with the gem's: stores upgraded from 5.x created one by hand, subscribed to
  # other events.
  class RegisterWebhook
    # @param payment_method [SpreePaypalCheckout::Gateway]
    # @return [Hash, nil] the webhook, or nil when the method has no URL
    def call(payment_method:)
      url = payment_method.webhook_url
      return if url.blank?

      events = SpreePaypalCheckout::Gateway::Webhooks::SUPPORTED_EVENTS
      client = payment_method.notifications_client
      existing = client.list_webhooks.find { |webhook| webhook['url'] == url }

      webhook = if existing
                  client.replace_webhook_events(existing['id'], events)
                else
                  client.create_webhook(url: url, event_types: events)
                end

      payment_method.update!(preferred_webhook_id: webhook['id']) if payment_method.preferred_webhook_id != webhook['id']
      webhook
    end
  end
end
