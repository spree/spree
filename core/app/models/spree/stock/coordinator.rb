module Spree
  module Stock
    mattr_accessor :default_splitters

    class Coordinator
      def packages(order)
        packages = Array.new
        StockLocation.all.each do |stock_location|
          packer = Packer.new(stock_location, order, splitters(stock_location))
          packages += packer.packages
        end

        #TODO prioritize packages!

        #TODO determine missing items
        packages
      end

      private
      def missing_items(order, packages)
        #TODO loop through and pull out packages
        []
      end

      def splitters(stock_location)
        # extension point to return custom splitters for a location
        Spree::Stock.default_splitters
      end
    end
  end
end
