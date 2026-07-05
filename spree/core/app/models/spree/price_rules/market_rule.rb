module Spree
  module PriceRules
    class MarketRule < Spree::PriceRule
      # Stored as raw IDs. Accepts prefixed IDs (`mkt_…`) from API
      # callers and decodes them on write so eligibility checks compare
      # against raw `market_id` rows directly. Scope confines the
      # existence check to the price-list's store so cross-store market
      # IDs can't sneak in.
      preference :market_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Market,
                   scope: ->(rule) { rule.store.markets }
                 )

      def markets
        return [] if preferred_market_ids.blank?

        Spree::Market.where(id: preferred_market_ids)
      end

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
