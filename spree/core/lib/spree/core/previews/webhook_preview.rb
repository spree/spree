# Preview Spree webhook notification emails at /rails/mailers/spree/webhook
class Spree::WebhookPreview < ActionMailer::Preview
  def endpoint_disabled
    Spree::WebhookMailer.endpoint_disabled(webhook_endpoint)
  end

  private

  # Reuse the most recent endpoint, or build an in-memory disabled example so the
  # preview works on a database with no webhook endpoints. Never saved, so the
  # admin webhook list stays clean.
  def webhook_endpoint
    Spree::WebhookEndpoint.last || example_endpoint
  end

  def example_endpoint
    Spree::WebhookEndpoint.new(
      store: Spree::Store.default,
      name: 'Example endpoint',
      url: 'https://example.com/webhooks/spree',
      active: false,
      disabled_reason: 'Too many failed delivery attempts',
      disabled_at: Time.current,
      subscriptions: ['order.completed']
    )
  end
end
