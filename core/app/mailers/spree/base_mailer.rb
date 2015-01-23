module Spree
  class BaseMailer < ActionMailer::Base

    def from_address
      Spree::Store.current.mails_from_address
    end

    def money(amount, currency = Spree::Store.current.default_currency)
      Spree::Money.new(amount, currency: currency).to_s
    end
    helper_method :money

    def mail(headers={}, &block)
      super if Spree::Config[:send_core_emails]
    end

  end
end
