module Spree
  module Stock
    mattr_accessor :default_splitters

    class Coordinator
      def packages(order)
        packages = Array.new
        StockLocation.all.each do |stock_location|
          packer = build_packer(stock_location, order)
          packages += packer.packages
          break if order_fulfilled?(order, packages)
        end


        finalize packages
      end

      private
      def order_fulfilled?(order, packages)
        variants = {}
        order.line_items.each { |li| variants[li.variant_id] = li.quantity }

        packages.each do |package|
          package.contents.each do |item|
            variants[item.variant.id] -= 1
          end
        end

        variants.values.all? {|value| value <= 0}
      end

      def finalize(packages)

        packages
      end

      def build_packer(stock_location, order)
        Packer.new(stock_location, order, splitters(stock_location))
      end

      def splitters(stock_location)
        # extension point to return custom splitters for a location
        Spree::Stock.default_splitters
      end
    end
  end
end
