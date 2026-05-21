module Spree
  class NewsletterMailer < BaseMailer
    # @param subscriber [Spree::NewsletterSubscriber]
    # @param redirect_url [String, nil] Storefront page that handles the verification token.
    #   When provided, the link is built as `<redirect_url>?token=<verification_token>`.
    #   Falls back to `<store.storefront_url>/?token=<verification_token>` for legacy setups.
    def email_confirmation(subscriber, redirect_url: nil)
      @subscriber = subscriber
      store = subscriber.store || Spree::Current.store || Spree::Store.default
      base_url = redirect_url.presence || store.storefront_url
      @confirm_email_url = append_token(base_url, @subscriber.verification_token)
      mail(to: @subscriber.email, from: from_address, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
    end

    private

    def append_token(url, token)
      separator = url.include?('?') ? '&' : '?'
      "#{url}#{separator}token=#{CGI.escape(token.to_s)}"
    end
  end
end
