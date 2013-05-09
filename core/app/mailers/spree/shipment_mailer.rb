module Spree
  class ShipmentMailer < BaseMailer
    def shipped_email(shipment, resend = false)
      @shipment = shipment.respond_to?(:id) ? shipment : Spree::Shipment.find(shipment)
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{Spree.t('shipment_mailer.shipped_email.subject')} ##{@shipment.order.number}"
      mail(to: @shipment.order.email, from: from_address, subject: subject)
    end
  end
end
