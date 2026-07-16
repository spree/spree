require_relative 'preview_data'

# Preview Spree webhook notification emails at /rails/mailers/spree/webhook
class Spree::WebhookPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def endpoint_disabled
    Spree::WebhookMailer.endpoint_disabled(webhook_endpoint)
  end

  private

  # Reuse the most recent endpoint, or build an in-memory disabled example so the
  # preview works on a database with no webhook endpoints. When the preview
  # toolbar requests a locale, always use the example so its store carries that
  # locale. Never saved, so the admin webhook list stays clean.
  def webhook_endpoint
    return example_endpoint if locale.present?

    Spree::WebhookEndpoint.last || example_endpoint
  end

  def example_endpoint
    Spree::WebhookEndpoint.new(
      store: Spree::PreviewData.store(locale),
      name: 'Example endpoint',
      url: 'https://example.com/webhooks/spree',
      active: false,
      disabled_reason: 'Too many failed delivery attempts',
      disabled_at: Time.current,
      subscriptions: ['order.completed']
    )
  end
end
