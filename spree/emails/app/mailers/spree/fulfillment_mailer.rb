module Spree
  class FulfillmentMailer < BaseMailer
    def fulfilled_email(fulfillment, resend = false)
      fulfillment_email(fulfillment, 'fulfilled_email', resend)
    end

    def delivered_email(fulfillment, resend: false)
      fulfillment_email(fulfillment, 'delivered_email', resend)
    end

    private

    def fulfillment_email(fulfillment, action, resend)
      @fulfillment = fulfillment.respond_to?(:id) ? fulfillment : Spree::Fulfillment.find(fulfillment)
      @order = @fulfillment.order
      @current_store = @fulfillment.store

      with_store_locale(current_store, @order.locale) do
        mail_template(
          {
            fulfillment: email_data(@fulfillment, Spree::Emails::FulfillmentSerializer),
            order: email_data(@order, Spree::Emails::OrderSerializer),
            resend: resend
          },
          template: "spree/fulfillment_mailer/#{action}",
          to: @order.email, store_url: current_store.storefront_url
        )
      end
    end
  end
end
