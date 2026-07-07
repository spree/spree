require 'spree/core/previews/preview_data'

# Preview Spree newsletter emails at /rails/mailers/spree/newsletter
class Spree::NewsletterPreview < ActionMailer::Preview
  def email_confirmation
    subscriber = (locale.blank? && Spree::NewsletterSubscriber.unverified.last) || example_subscriber
    Spree::NewsletterMailer.email_confirmation(subscriber)
  end

  private

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

  def locale
    @params[:locale]
  end
end
