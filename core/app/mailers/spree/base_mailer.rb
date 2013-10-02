module Spree
  class BaseMailer < ActionMailer::Base
    def from_address
      Spree::Config[:mails_from]
    end

    def money(amount)
      Spree::Money.new(amount).to_s
    end
    helper_method :money

    alias_method :orig_mail, :mail

    def mail(headers={}, &block)
      if Spree::Config[:send_core_emails]
        orig_mail
      end
    end

  end
end
