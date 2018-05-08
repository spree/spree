module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location

      def initialize(variant, stock_location = nil)
        @variant        = variant
        @stock_location = stock_location
      end

      def total_on_hand
        if variant.should_track_inventory?
          stock_items.sum(:count_on_hand)
        else
          Float::INFINITY
        end
      end

      def backorderable?
        stock_items.any?(&:backorderable)
      end

      def can_supply?(required = 1)
        variant.available? && (total_on_hand >= required || backorderable?)
      end

      def stock_items
        @stock_items ||= scope_to_location(variant.stock_items)
      end

      private

      def scope_to_location(collection)
        return collection.with_active_stock_location unless stock_location.present?

        collection.where(stock_location: stock_location)
      end
    end
  end
end
