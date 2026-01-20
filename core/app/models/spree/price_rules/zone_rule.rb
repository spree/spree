module Spree
  module PriceRules
    class ZoneRule < Spree::PriceRule
      preference :zone_ids, :array, default: []

      def applicable?(context)
        return false unless context.zone
        return true if preferred_zone_ids.empty?

        # Compare as strings to support both integer and UUID primary keys
        preferred_zone_ids.map(&:to_s).include?(context.zone.id.to_s)
      end

      def self.description
        'Apply pricing based on the tax/shipping zone'
      end
    end
  end
end
