module Spree
  module Stock
    class Coordinator
      attr_reader :order

      def initialize(order)
        @order = order
      end

      def packages
        packages = Array.new
        packages = build_packages(packages)
        packages = prioritize_packages(packages)
        packages = estimate_packages(packages)
      end

      private
      def build_packages(packages)
        StockLocation.active.each do |stock_location|
          packer = build_packer(stock_location, order)
          packages += packer.packages
        end
        packages
      end

      def prioritize_packages(packages)
        prioritizer = Prioritizer.new(order, packages)
        prioritizer.prioritized_packages
      end

      def estimate_packages(packages)
        estimator = Estimator.new(order)
        packages.each do |package|
          package.shipping_rates = estimator.shipping_rates(package)
        end
        packages
      end

      def build_packer(stock_location, order)
        Packer.new(stock_location, order, splitters(stock_location))
      end

      def splitters(stock_location)
        # extension point to return custom splitters for a location
        Rails.application.config.spree.stock_splitters
      end
    end
  end
end
