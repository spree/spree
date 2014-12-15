module Spree
  class ReturnItem::EligibilityValidator::InventoryShipped < Spree::ReturnItem::EligibilityValidator::BaseValidator
    def eligible_for_return?
      if @return_item.inventory_unit.shipped?
        return true
      else
        add_error(:inventory_unit_shipped, Spree.t('return_item_inventory_unit_ineligible'))
        return false
      end
    end

    def requires_manual_intervention?
      @errors.present?
    end
  end
end
