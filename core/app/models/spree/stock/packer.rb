module Spree
  module Stock
    class Packer
<<<<<<< HEAD
      attr_reader :stock_location, :order, :splitters

      def initialize(stock_location, order, splitters=[Splitter::Base])
        @stock_location = stock_location
        @order = order
        @splitters = splitters
=======
      attr_accessor :stock_location, :order, :splitter_class

      def initialize(stock_location, order, splitter_class=Splitter::Base)
        @stock_location = stock_location
        @order = order
        @splitter_class = splitter_class
>>>>>>> chain of responsibility for splitters
      end

      def packages
        build_splitter.split [default_package]
      end

      def default_package
        package = Package.new(stock_location, order)
        order.line_items.each do |line_item|
          on_hand, backordered = stock_location.fill_status(line_item.variant, line_item.quantity)
          package.add line_item.variant, on_hand, :on_hand if on_hand > 0
          package.add line_item.variant, backordered, :backordered if backordered > 0
        end
        package
      end

<<<<<<< HEAD
=======
      def build_splitter
        # TODO build a chain of splitters
        splitter_class.new(self)
      end

>>>>>>> chain of responsibility for splitters
      private
      def build_splitter
        splitter = nil
        splitters.reverse.each do |klass|
          splitter = klass.new(self, splitter)
        end
        splitter
      end
    end
  end
end
