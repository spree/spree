module Spree
  class BaseMailer < ActionMailer::Base
    def from_address
      Spree::Store.current.mail_from_address
    end

    def money(amount, currency = Spree::Config[:currency])
      Spree::Money.new(amount, currency: currency).to_s
    end
    helper_method :money

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end
    helper_method :frontend_available?

    def mail(headers = {}, &block)
      ensure_default_action_mailer_url_host
      super if Spree::Config[:send_core_emails]
    end

    private

    # this ensures that ActionMailer::Base.default_url_options[:host] is always set
    # this is only a fail-safe solution if developer didn't set this in environment files
    # http://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views
    def ensure_default_action_mailer_url_host
      ActionMailer::Base.default_url_options ||= {}
      ActionMailer::Base.default_url_options[:host] ||= Spree::Store.current.url
    end
  end
end
