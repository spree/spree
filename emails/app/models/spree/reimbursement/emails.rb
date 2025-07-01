module Spree
  class Reimbursement < Spree.base_class
    module Emails
      def send_reimbursement_email
        Spree::ReimbursementMailer.reimbursement_email(id).deliver_later if store.prefers_send_consumer_transactional_emails?
      end
    end
  end
end
