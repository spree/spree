module Spree
  module Stock
    class Packer
      attr_accessor :stock_location, :order, :splitter_class

      def initialize(stock_location, order, splitter_class=Splitter::Base)
        @stock_location = stock_location
        @order = order
        @splitter_class = splitter_class
      end

      def packages
        build_splitter.split [default_package]
      end

      def default_package
        package = Package.new(stock_location)
        order.line_items.each do |line_item|
          on_hand, backordered = stock_status(line_item.variant, line_item.quantity)
          package.add line_item.variant, on_hand, :on_hand if on_hand > 0
          package.add line_item.variant, backordered, :backordered if backordered > 0
        end
        package
      end

      def build_splitter
        # TODO build a chain of splitters
        splitter_class.new(self)
      end

      private
      def stock_status(variant, quantity)
        item = stock_location.stock_item(variant)

        if item.count_on_hand >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.count_on_hand
          backordered = quantity - on_hand
        end

        [on_hand, backordered]
      end
    end
  end
end
