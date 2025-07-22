module Spree
  module TaxonRules
    class AvailableOn < Spree::TaxonRule
      def apply(scope)
        # value here is no of weeks
        # eg. return products that become available in the last 2 weeks
        timezone = taxon.store.preferred_timezone
        date = value.to_i.days.ago.beginning_of_day.in_time_zone(timezone)

        if match_policy == 'is_equal_to'
          scope.where(['spree_products.created_at >= ?', date]).or(
            scope.where(['spree_products.available_on >= ?', date])
          )
        else
          scope
        end
      end
    end
  end
end
