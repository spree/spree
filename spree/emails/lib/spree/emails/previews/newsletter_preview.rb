require 'spree/core/previews/preview_data'

# Preview Spree newsletter emails at /rails/mailers/spree/newsletter
class Spree::NewsletterPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def email_confirmation
    Spree::NewsletterMailer.email_confirmation(subscriber)
  end

  private

  def subscriber
    return example_subscriber if locale.present?

    Spree::NewsletterSubscriber.unverified.last || example_subscriber
  end

  # Build an in-memory subscriber so the preview works on a database with no
  # newsletter subscribers. When the preview toolbar requests a locale, its
  # store carries that locale. Never saved, so no records are created.
  def example_subscriber
    subscriber = Spree::NewsletterSubscriber.new(
      email: 'guest@example.com',
      store: Spree::PreviewData.store(locale)
    )
    subscriber.verification_token ||= 'preview-token'
    subscriber
  end
end
