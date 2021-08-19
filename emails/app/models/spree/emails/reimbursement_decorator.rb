module Spree
  module Emails
    module ReimbursementDecorator
      def send_reimbursement_email
        Spree::ReimbursementMailer.reimbursement_email(id).deliver_later
      end

      ::Spree::Reimbursement.prepend(self)
    end
  end
end
