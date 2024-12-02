module Spree
  class Reimbursement < Spree.base_class
    module Emails
      def send_reimbursement_email
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
        # YourEmailVendor.deliver_reimbursement_email(id) # `id` = ID of the Reimbursement being sent, you can also pass the entire object using `self`
      end
    end
  end
end
