module Spree
  class ShipmentMailer < BaseMailer
    helper Spree::MailHelper
    helper Spree::ShipmentHelper

    def shipped_email(shipment, resend = false)
      @shipment = shipment.respond_to?(:id) ? shipment : Spree::Shipment.find(shipment)
      @order = @shipment.order
      current_store = @shipment.store
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('shipment_mailer.shipped_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.storefront_url)
      end
    end
  end
end
