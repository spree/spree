# Preview Spree newsletter emails at /rails/mailers/spree/newsletter
class Spree::NewsletterPreview < ActionMailer::Preview
  def email_confirmation
    subscriber = Spree::NewsletterSubscriber.unverified.last || Spree::NewsletterSubscriber.last
    Spree::NewsletterMailer.email_confirmation(subscriber)
  end
end
