module Spree
  class NewsletterMailer < BaseMailer
    def email_confirmation(subscriber, redirect_url: nil)
      @subscriber = subscriber
      store = subscriber.store || Spree::Current.store || Spree::Store.default
      base_url = redirect_url.presence || store.storefront_url
      @confirm_email_url = append_token(base_url, @subscriber.verification_token)
      with_store_locale(store) do
        mail(to: @subscriber.email, from: from_address, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
      end
    end

  end
end
