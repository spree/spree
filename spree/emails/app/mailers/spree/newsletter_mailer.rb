module Spree
  class NewsletterMailer < BaseMailer
    def email_confirmation(subscriber, redirect_url: nil)
      @subscriber = subscriber
      store = subscriber.store || Spree::Current.store || Spree::Store.default
      base_url = redirect_url.presence || store.storefront_url
      @confirm_email_url = append_token(base_url, @subscriber.verification_token)
      mail(to: @subscriber.email, from: from_address, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
    end

    private

    # URI-based merge preserves existing query params and fragments so the token
    # doesn't get swallowed by a `#section` or clobber an existing `?source=`.
    def append_token(url, token)
      uri = URI.parse(url.to_s)
      params = URI.decode_www_form(uri.query || '')
      params << ['token', token.to_s]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      separator = url.include?('?') ? '&' : '?'
      "#{url}#{separator}token=#{CGI.escape(token.to_s)}"
    end
  end
end
