module Spree
  module Stock
    mattr_accessor :default_splitters

    class Coordinator
      attr_reader :order

      def initialize(order)
        @order = order
      end

      def packages
        packages = Array.new
        packages = build_packages(packages)
        packages = prioritize_packages(packages)
      end

      private
      def build_packages(packages)
        StockLocation.all.each do |stock_location|
          packer = build_packer(stock_location, order)
          packages += packer.packages
          break if order_fulfilled?(order, packages)
        end
        packages
      end

      def prioritize_packages(packages)
        prioritizer = Prioritizer.new(order, packages)
        prioritizer.prioritized_packages
      end

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
