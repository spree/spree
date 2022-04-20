module Spree
  class ReimbursementMailer < BaseMailer
    def reimbursement_email(reimbursement, resend = false)
      @reimbursement = reimbursement.respond_to?(:id) ? reimbursement : Spree::Reimbursement.find(reimbursement)
      @order = @reimbursement.order
      current_store = @reimbursement.store || Spree::Store.default
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('reimbursement_mailer.reimbursement_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url, reply_to: reply_to_address)
    end
  end
end
