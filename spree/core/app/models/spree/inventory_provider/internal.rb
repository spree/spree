module Spree
  module InventoryProvider
    # Spree's own stock records. Returns the association untouched so
    # {Spree::Stock::Quantifier} keeps its loaded-association fast path — a
    # preloaded variant must not fall back to a query per stock item.
    #
    # Location narrowing and active-location filtering stay in the Quantifier,
    # which already does both; doing them here as well would break that
    # preload branch for no gain.
    class Internal < Base
      # @param variant [Spree::Variant]
      # @param stock_location [Spree::StockLocation, nil]
      # @return [Enumerable<Spree::StockLevel>]
      def stock_levels_for(variant, stock_location: nil)
        return variant.stock_levels if stock_location.blank?
        return variant.stock_levels.select { |item| item.stock_location_id == stock_location.id } if variant.association(:stock_levels).loaded?

        variant.stock_levels.where(stock_location: stock_location)
      end
    end
  end
end
