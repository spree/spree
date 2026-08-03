module Spree
  class FulfillmentMailer < BaseMailer
    helper Spree::MailHelper
    helper Spree::FulfillmentHelper

    def fulfilled_email(fulfillment, resend = false)
      @fulfillment = fulfillment.respond_to?(:id) ? fulfillment : Spree::Fulfillment.find(fulfillment)
      @order = @fulfillment.order
      current_store = @fulfillment.store
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('fulfillment_mailer.fulfilled_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, subject: subject, store_url: current_store.storefront_url,
             template_path: 'spree/fulfillment_mailer', template_name: 'fulfilled_email')
      end
    end
  end
end
