module Spree
  class ReturnMailer < BaseMailer
    helper Spree::MailHelper

    # Tells the customer their returned items were refunded. Replaces the
    # reimbursement email dropped with the ReturnAuthorization chain in 6.0.
    def refunded_email(return_record, resend = false)
      @return = return_record.respond_to?(:id) ? return_record : Spree::Return.find(return_record)
      @order = @return.order
      current_store = @return.store || Spree::Store.default
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('return_mailer.refunded_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, subject: subject, store_url: current_store.storefront_url)
      end
    end
  end
end
