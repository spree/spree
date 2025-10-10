module Spree
  class ShipmentMailer < BaseMailer
    helper Spree::ShipmentHelper

    def shipped_email(shipment, resend = false)
      @shipment = shipment.respond_to?(:id) ? shipment : Spree::Shipment.find(shipment)
      @order = @shipment.order
      current_store = @shipment.store
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('shipment_mailer.shipped_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url_or_custom_domain, reply_to: reply_to_address)
    end
  end
end
