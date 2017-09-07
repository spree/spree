module Spree
  module Stock
    class Quantifier
      attr_reader :stock_items, :variant

      def initialize(variant)
        @variant = variant
        @stock_items = @variant.stock_items.with_active_stock_location
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
    end
  end
end
