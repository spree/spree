# frozen_string_literal: true

module Spree
  class CustomerMailer < BaseMailer
    def password_reset_email(user_id, store_id, reset_token, redirect_url = nil)
      @user = Spree.user_class.find(user_id)
      @current_store = Spree::Store.find(store_id)
      @reset_token = reset_token
      @reset_url = build_reset_url(redirect_url, reset_token)

      subject = "#{@current_store.name} #{Spree.t('customer_mailer.password_reset_email.subject')}"
      mail(
        to: @user.email,
        from: from_address,
        subject: subject,
        store_url: @current_store.storefront_url,
        reply_to: reply_to_address
      )
    end

    private

    def build_reset_url(redirect_url, token)
      return nil if redirect_url.blank?

      uri = URI.parse(redirect_url)
      params = URI.decode_www_form(uri.query || '')
      params << ['token', token]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end
  end
end
