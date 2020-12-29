module Spree
  module Admin
    module CustomerReturnsHelper
      def reimbursement_types
        @reimbursement_types ||= Spree::ReimbursementType.accessible_by(current_ability).active
      end
    end
  end
end
