module Spree
  module Stock
    class Packer
      attr_reader :stock_location, :order, :splitters

      def initialize(stock_location, order, splitters=[Splitter::Base])
        @stock_location = stock_location
        @order = order
        @splitters = splitters
      end

      def packages
        build_splitter.split [default_package]

        # packages container object to tell you
        # if complete or missing
        #
        # packages fulfill entire order?
        # and return missing
      end

      def default_package
        package = Package.new(stock_location, order)
        order.line_items.each do |line_item|
          on_hand, backordered = stock_status(line_item.variant, line_item.quantity)
          package.add line_item.variant, on_hand, :on_hand if on_hand > 0
          package.add line_item.variant, backordered, :backordered if backordered > 0
        end
        package
      end

      private
      def build_splitter
        splitter = nil
        splitters.reverse.each do |klass|
          splitter = klass.new(self, splitter)
        end
        splitter
      end

      def stock_status(variant, quantity)
        item = stock_location.stock_item(variant)

        if item.count_on_hand >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.count_on_hand
          backordered = quantity - on_hand if item.backorderable?
        end

        [on_hand, backordered]
      end
    end
  end
end
