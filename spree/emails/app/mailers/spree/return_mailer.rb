module Spree
  class ReturnMailer < BaseMailer
    # Tells the customer their returned items were refunded. Replaces the
    # reimbursement email dropped with the ReturnAuthorization chain in 6.0.
    def refunded_email(return_record, resend = false)
      @return = return_record.respond_to?(:id) ? return_record : Spree::Return.find(return_record)
      @order = @return.order
      @current_store = @return.store || Spree::Store.default

      with_store_locale(current_store, @order.locale) do
        mail_template(
          {
            return: email_data(@return, Spree::Emails::ReturnSerializer, currency: @order.currency),
            order: email_data(@order, Spree::Emails::OrderSerializer, currency: @order.currency),
            resend: resend
          },
          to: @order.email, currency: @order.currency, store_url: current_store.storefront_url
        )
      end
    end
  end
end
