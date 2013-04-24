module Spree
  module Stock
    class OrderCounter
      attr_reader :order

      def initialize(order)
        @order = order
        @ordered_counts = count_line_items
        @assigned_counts = count_inventory_units
      end

      def variants
        @ordered_counts.keys
      end

      def variants_with_remaining
        variants.select { |variant| remaining(variant) > 0 }
      end

      def remaining?
        not variants_with_remaining.empty?
      end

      def ordered(variant)
        @ordered_counts[variant]
      end

      def assigned(variant)
        @assigned_counts[variant]
      end

      def remaining(variant)
        @ordered_counts[variant] - @assigned_counts[variant]
      end

      private
      def count_line_items
        counts = Hash.new(0)
        order.line_items.each do |line_item|
          counts[line_item.variant] += line_item.quantity
        end
        counts
      end

      def count_inventory_units
        counts = Hash.new(0)
        order.inventory_units.each do |inventory_unit|
          counts[inventory_unit.variant] += 1
        end
        counts
      end
    end
  end
end

