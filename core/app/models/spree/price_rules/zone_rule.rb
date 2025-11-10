module Spree
  module PriceRules
    class ZoneRule < Spree::PriceRule
      preference :zone_ids, :array, default: []

      def applicable?(context)
        return false unless context.zone
        return true if preferred_zone_ids.empty?

        preferred_zone_ids.include?(context.zone.id)
      end

      def self.description
        'Apply pricing based on the tax/shipping zone'
      end
    end
  end
end
