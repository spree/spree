module Spree
  class ReturnItem::EligibilityValidator::TimeSincePurchase < Spree::ReturnItem::EligibilityValidator::BaseValidator
    def eligible_for_return?
      if (@return_item.inventory_unit.order.completed_at + Spree::Config[:return_eligibility_number_of_days].days) > Time.now
        return true
      else
        add_error(:number_of_days, Spree.t('return_item_time_period_ineligible'))
        return false
      end
    end

    def requires_manual_intervention?
      false
    end
  end
end
