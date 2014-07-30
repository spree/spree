module Spree
  class ReturnItem::ReturnEligibilityValidator
    attr_reader :errors

    def initialize(return_item)
      @return_item = return_item
      @errors = {}
    end

    def eligible_for_return?
      if (@return_item.inventory_unit.created_at + Spree::Config[:return_eligibility_number_of_days].days) > Time.now
        return true
      else
        @errors[:number_of_days] = Spree.t('return_item_time_period_ineligible')
        return false
      end
    end

    # Overwrite this if there are conditions in which you'd like to manually intervene
    def requires_manual_intervention?
      false
    end
  end
end
