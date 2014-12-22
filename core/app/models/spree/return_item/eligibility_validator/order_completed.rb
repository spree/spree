module Spree
  class ReturnItem::EligibilityValidator::OrderCompleted < Spree::ReturnItem::EligibilityValidator::BaseValidator
    def eligible_for_return?
      if @return_item.inventory_unit.order.completed?
        return true
      else
        add_error(:order_not_completed, Spree.t('return_item_order_not_completed'))
        return false
      end
    end

    def requires_manual_intervention?
      false
    end
  end
end
