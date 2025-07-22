module Spree
  module Stock
    class Quantifier
      attr_reader :variant, :stock_location

      def initialize(variant, stock_location = nil)
        @variant        = variant
        @stock_location = stock_location
      end

      def total_on_hand
        @total_on_hand ||= if variant.should_track_inventory?
                             if association_loaded?
                               stock_items.sum(&:count_on_hand)
                             else
                               stock_items.sum(:count_on_hand)
                             end
                           else
                             BigDecimal::INFINITY
                           end
      end

      def backorderable?
        @backorderable ||= stock_items.any?(&:backorderable)
      end

      def can_supply?(required = 1)
        variant.available? && (total_on_hand >= required || backorderable?)
      end

      def stock_items
        @stock_items ||= scope_to_location(variant.stock_items)
      end

      private

      def association_loaded?
        variant.association(:stock_items).loaded? && variant.association(:stock_locations).loaded?
      end

      def scope_to_location(collection)
        if stock_location.blank?
          if association_loaded?
            return collection.select { |si| si.stock_location&.active? }
          else
            return collection.with_active_stock_location
          end
        end

        if association_loaded?
          collection.select { |si| si.stock_location_id == stock_location.id }
        else
          collection.where(stock_location: stock_location)
        end
      end
    end
  end
end
