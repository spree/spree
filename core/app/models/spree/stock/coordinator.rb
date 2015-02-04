module Spree
  module Stock
    class Coordinator
      attr_reader :order, :inventory_units

      def initialize(order, inventory_units = nil)
        @order = order
        @inventory_units = inventory_units || InventoryUnitBuilder.new(order).units
      end

      def shipments
        packages.map do |package|
          package.to_shipment.tap { |s| s.address = order.ship_address }
        end
      end

      def packages
        packages = build_packages
        packages = prioritize_packages(packages)
        packages = estimate_packages(packages)
      end

      # Build packages as per stock location
      #
      # It needs to check whether each stock location holds at least one stock
      # item for the order. In case none is found it wouldn't make any sense
      # to build a package because it would be empty. Plus we avoid errors down
      # the stack because it would assume the stock location has stock items
      # for the given order
      # 
      # Returns an array of Package instances
      def build_packages(packages = Array.new)
        StockLocation.active.each do |stock_location|
          next unless stock_location.stock_items.where(:variant_id => inventory_units.map(&:variant_id).uniq).exists?

          packer = build_packer(stock_location, inventory_units)
          packages += packer.packages
        end
        packages
      end

      private
      def prioritize_packages(packages)
        prioritizer = Prioritizer.new(inventory_units, packages)
        prioritizer.prioritized_packages
      end

      def estimate_packages(packages)
        estimator = Estimator.new(order)
        packages.each do |package|
          package.shipping_rates = estimator.shipping_rates(package)
        end
        packages
      end

      def build_packer(stock_location, inventory_units)
        Packer.new(stock_location, inventory_units, splitters(stock_location))
      end

      def splitters(stock_location)
        # extension point to return custom splitters for a location
        Rails.application.config.spree.stock_splitters
      end
    end
  end
end
