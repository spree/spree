module Spree
  class NewsletterMailer < BaseMailer
    def email_confirmation(subscriber, redirect_url: nil)
      @subscriber = subscriber
      store = subscriber.store || Spree::Current.store || Spree::Store.default
      # The shared header/footer and from address read current_store — set it
      # to the subscriber's store so multi-store installs brand correctly.
      @current_store = store
      base_url = redirect_url.presence || store.storefront_url
      @confirm_email_url = append_token(base_url, @subscriber.verification_token)
      with_store_locale(store) do
        mail(to: @subscriber.email, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
      end
    end

  end
end
