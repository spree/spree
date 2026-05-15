module Spree
  class NewsletterMailer < BaseMailer
    def email_confirmation(subscriber)
      @subscriber = subscriber
      store = subscriber.store || Spree::Current.store || Spree::Store.default
      @confirm_email_url = spree.verify_newsletter_subscribers_url(token: @subscriber.verification_token, host: store.storefront_url)
      mail(to: @subscriber.email, from: from_address, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
    end
  end
end
