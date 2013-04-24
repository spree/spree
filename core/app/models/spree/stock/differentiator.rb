module Spree
  module Stock
    class Differentiator
      attr_reader :missing, :packed, :required, :packages, :order

      def initialize(order, packages)
        @order = order
        @packages = packages
        build_packed
        build_required
        build_missing
      end

      def missing?
        missing.values.any? { |v| v > 0 }
      end

      private
      def build_missing
        @missing = Hash.new(0)
        required.keys.each do |variant|
           missing = required[variant] - packed[variant]
           @missing[variant] = missing if missing > 0
        end
      end

      def build_packed
        @packed = Hash.new(0)
        packages.each do |package|
          package.contents.each do |content_item|
            @packed[content_item.variant] += content_item.quantity
          end
        end
      end

      def build_required
        @required = Hash.new(0)
        order.line_items.each do |line_item|
          @required[line_item.variant] = line_item.quantity
        end
      end
    end
  end
end
