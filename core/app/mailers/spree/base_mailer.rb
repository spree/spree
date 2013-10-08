module Spree
  class BaseMailer < ActionMailer::Base
    def from_address
      Spree::Config[:mails_from]
    end

    def money(amount)
      Spree::Money.new(amount).to_s
    end
    helper_method :money

    def mail(headers={}, &block)
      super if Spree::Config[:send_core_emails]
    end

  end
end
