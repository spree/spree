module Spree
  class ReimbursementMailer < BaseMailer
      def reimbursement_email(reimbursement, resend = false)
        @reimbursement = reimbursement.respond_to?(:id) ? reimbursement : Spree::Reimbursement.find(reimbursement)
        @store = @reimbursement.order.store
        subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
        subject += "#{@store} #{Spree.t('reimbursement_mailer.reimbursement_email.subject')} ##{@reimbursement.order.number}"
        mail(to: @reimbursement.order.email, from: from_address, subject: subject)
      end
  end
end
