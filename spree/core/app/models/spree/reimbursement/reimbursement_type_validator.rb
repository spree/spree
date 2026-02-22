module Spree
  module Reimbursement::ReimbursementTypeValidator
    def valid_preferred_reimbursement_type?(return_item)
      preferred_type = return_item.preferred_reimbursement_type.class

      !past_reimbursable_time_period?(return_item) ||
        preferred_type == expired_reimbursement_type
    end

    def past_reimbursable_time_period?(return_item)
      shipped_at = return_item.inventory_unit.shipment.shipped_at
      shipped_at && shipped_at < refund_time_constraint.ago
    end
  end
end
