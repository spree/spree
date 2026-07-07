module Spree
  class ReimbursementMailer < BaseMailer
    helper Spree::MailHelper

    def reimbursement_email(reimbursement, resend = false)
      @reimbursement = reimbursement.respond_to?(:id) ? reimbursement : Spree::Reimbursement.find(reimbursement)
      @order = @reimbursement.order
      current_store = @reimbursement.store || Spree::Store.default
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('reimbursement_mailer.reimbursement_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.storefront_url, reply_to: reply_to_address)
      end
    end
  end
end
