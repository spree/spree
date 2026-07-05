# Preview Spree newsletter emails at /rails/mailers/spree/newsletter
class Spree::NewsletterPreview < ActionMailer::Preview
  def email_confirmation
    subscriber = Spree::NewsletterSubscriber.unverified.last || example_subscriber
    Spree::NewsletterMailer.email_confirmation(subscriber)
  end

  private

  # Build an in-memory subscriber so the preview works on a database with no
  # newsletter subscribers. Never saved, so no records are created.
  def example_subscriber
    subscriber = Spree::NewsletterSubscriber.new(
      email: 'guest@example.com',
      store: Spree::Store.default
    )
    subscriber.verification_token ||= 'preview-token'
    subscriber
  end
end
