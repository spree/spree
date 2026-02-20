module Spree
  module PriceRules
    class MarketRule < Spree::PriceRule
      preference :market_ids, :array, default: []

      def applicable?(context)
        return false unless context.market
        return true if preferred_market_ids.empty?

        # Compare as strings to support both integer and UUID primary keys
        preferred_market_ids.map(&:to_s).include?(context.market.id.to_s)
      end

      def self.description
        'Apply pricing based on the market'
      end
    end
  end
end
