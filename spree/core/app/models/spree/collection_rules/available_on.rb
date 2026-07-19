# frozen_string_literal: true

module Spree
  module CollectionRules
    class AvailableOn < Spree::CollectionRule
      # value is the number of days; matches products created/available within that window.
      def apply(scope)
        timezone = collection.store.preferred_timezone
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
