module Spree
  module Stock
    class RemainingPacker < Packer
      attr_reader :order_counter

      def initialize(stock_location, order, order_counter=nil)
        super
        @order_counter = order_counter || Stock::OrderCounter.new(order)
      end

      def default_package
        package = Package.new(stock_location, order)
        order_counter.variants_with_remaining.each do |variant|
          on_hand, backordered = stock_status(variant, order_counter.remaining(variant))
          package.add variant, on_hand, :on_hand if on_hand > 0
          package.add variant, backordered, :backordered if backordered > 0
        end
        package
      end
    end
  end
end
