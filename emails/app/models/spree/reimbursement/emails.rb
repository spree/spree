module Spree
  class Reimbursement < Spree.base_class
    module Emails
      def send_reimbursement_email
        Spree::ReimbursementMailer.reimbursement_email(id).deliver_later
      end
    end
  end
end
