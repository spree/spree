module Spree
  class ReturnItem::EligibilityValidator::NoReimbursements < Spree::ReturnItem::EligibilityValidator::BaseValidator
    def eligible_for_return?
      if Spree::ReturnItem.where(inventory_unit: @return_item.inventory_unit).where.not(reimbursement_id: nil).any?
        add_error(:inventory_unit_reimbursed, Spree.t('return_item_inventory_unit_reimbursed'))
        false
      else
        true
      end
    end

    def requires_manual_intervention?
      @errors.present?
    end
  end
end
