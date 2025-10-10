module Spree
  class BaseMailer < ActionMailer::Base
    helper Spree::MailHelper

    def current_store
      @current_store ||= @order&.store.presence || Spree::Store.current || Spree::Store.default
    end

    helper_method :current_store

    def from_address
      current_store.mail_from_address
    end

    def reply_to_address
      current_store.mail_from_address
    end

    def money(amount, currency = nil)
      currency ||= current_store.default_currency
      Spree::Money.new(amount, currency: currency).to_s
    end
    helper_method :money

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end
    helper_method :frontend_available?

    def mail(headers = {}, &block)
      ensure_default_action_mailer_url_host(headers[:store_url])
      set_email_locale
      super if Spree::Config[:send_core_emails]
    end

    private

    # this ensures that ActionMailer::Base.default_url_options[:host] is always set
    # this is only a fail-safe solution if developer didn't set this in environment files
    # http://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views
    def ensure_default_action_mailer_url_host(store_url = nil)
      host_url = store_url.presence || current_store.try(:url_or_custom_domain)

      return if host_url.blank?

      ActionMailer::Base.default_url_options ||= {}
      ActionMailer::Base.default_url_options[:host] = host_url
    end

    def set_email_locale
      locale = @order&.store&.default_locale || current_store&.default_locale
      I18n.locale = locale if locale.present?
    end
  end
end
