module Spree
  module Reimbursement::ReimbursementTypeValidator
    def valid_preferred_reimbursement_type?(return_item)
      !past_reimbursable_time_period?(return_item) || return_item.preferred_reimbursement_type == expired_reimbursement_type
    end

    def past_reimbursable_time_period?(return_item)
      shipped_at = return_item.inventory_unit.shipment.shipped_at
      shipped_at && shipped_at < refund_time_constraint.ago
    end
  end
end
