module Spree
  class ShipmentMailer < ActionMailer::Base

    def money(amount)
      Spree::Money.new(amount).to_s
    end
    helper_method :money

    def shipped_email(shipment, resend = false)
      @shipment = shipment
      subject = (resend ? "[#{t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{t('shipment_mailer.shipped_email.subject')} ##{shipment.order.number}"
      mail(:to => shipment.order.email,
           :subject => subject)
    end
  end
end
