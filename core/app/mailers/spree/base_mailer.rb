module Spree
  class BaseMailer < ActionMailer::Base
    def from_address
      if MailMethod.current
        MailMethod.current.preferred_mails_from
      else
        Spree::Config.emails_sent_from
      end
    end

    def money(amount)
      Spree::Money.new(amount).to_s
    end
    helper_method :money
  end
end
