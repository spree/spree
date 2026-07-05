# Preview Spree webhook notification emails at /rails/mailers/spree/webhook
class Spree::WebhookPreview < ActionMailer::Preview
  def endpoint_disabled
    Spree::WebhookMailer.endpoint_disabled(webhook_endpoint)
  end

  private

  # Reuse the most recent endpoint, or build a renderable disabled one on the
  # fly so the preview works on a database that has no webhook endpoints.
  def webhook_endpoint
    Spree::WebhookEndpoint.last || create_example_endpoint
  end

  def create_example_endpoint
    Spree::WebhookEndpoint.create!(
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
