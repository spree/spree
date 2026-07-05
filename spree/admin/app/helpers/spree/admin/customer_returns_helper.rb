module Spree
  module Admin
    module CustomerReturnsHelper
      def reimbursement_types
        @reimbursement_types ||= Spree::ReimbursementType.accessible_by(current_ability).active
      end

      def reimbursement_status_color(reimbursement)
        case reimbursement.reimbursement_status
        when 'reimbursed' then 'success'
        when 'pending' then 'notice'
        when 'errored' then 'error'
        else raise "unknown reimbursement status: #{reimbursement.reimbursement_status}"
        end
      end
    end
  end
end
