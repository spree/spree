module Spree
  module Stock
    class Quantifier
      attr_reader :stock_items

      def initialize(variant)
        @variant = variant
        @stock_items = Spree::StockItem.joins(:stock_location).where(variant_id: @variant, Spree::StockLocation.table_name => { active: true })
      end

      def total_on_hand
        if @variant.should_track_inventory?
          stock_items.sum(:count_on_hand)
        else
          Float::INFINITY
        end
      end

      def backorderable?
        stock_items.any?(&:backorderable)
      end

      def can_supply?(required)
        total_on_hand >= required || backorderable?
      end

    end
  end
end
