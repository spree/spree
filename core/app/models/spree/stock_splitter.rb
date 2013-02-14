module Spree
  module StockSplitter
    class Base
      attr_accessor :stock_location, :order

      def initialize(stock_location, order)
        @stock_location = stock_location
        @order = order
      end

      def split(packages)
        packages
      end
    end

    class ShippingCategory < Base
      def split(packages)
        #TODO regroup items by shipping category
        packages
      end
    end
  end
end
