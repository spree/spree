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
            return: email_data(@return, Spree::Emails::ReturnSerializer),
            order: email_data(@order, Spree::Emails::OrderSerializer),
            resend: resend
          },
          to: @order.email, store_url: current_store.storefront_url
        )
      end
    end
  end
end
