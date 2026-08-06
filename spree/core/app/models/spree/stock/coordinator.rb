module Spree
  module Stock
    class Coordinator
      attr_reader   :order, :inventory_units
      attr_accessor :unallocated_inventory_units

      def initialize(order, inventory_units = nil)
        @order = order
        @inventory_units = inventory_units || InventoryUnitBuilder.new(order).units
      end

      def fulfillments
        packages.map do |package|
          package.to_fulfillment.tap { |fulfillment| fulfillment.address_id = order.ship_address_id }
        end
      end

      # @deprecated Use {#fulfillments}; removed in 6.1.
      def shipments
        Spree::Deprecation.warn('Spree::Stock::Coordinator#shipments is deprecated and will be removed in Spree 6.1. Use #fulfillments instead.')
        fulfillments
      end

      def packages
        packages = build_packages
        packages = prioritize_packages(packages)
        packages = estimate_packages(packages)
      end

      def build_packages(packages = [])
        stock_locations_with_requested_variants.each do |stock_location|
          packer = build_packer(stock_location, inventory_units)
          packages += packer.packages
        end

        packages
      end

      private

      def stock_locations_with_requested_variants
        order.store.stock_locations.active.joins(:stock_items).
          where(spree_stock_items: { variant_id: requested_variant_ids }).distinct
      end

      def requested_variant_ids
        inventory_units.map(&:variant_id).uniq
      end

      def prioritize_packages(packages)
        prioritizer = Prioritizer.new(packages)
        prioritizer.prioritized_packages
      end

      def estimate_packages(packages)
        estimator = Estimator.new(order)
        packages.each do |package|
          package.delivery_rates = estimator.delivery_rates(package)
        end
        packages
      end

      def build_packer(stock_location, inventory_units)
        Packer.new(stock_location, inventory_units, splitters(stock_location))
      end

      def splitters(_stock_location)
        # extension point to return custom splitters for a location
        Spree.stock_splitters
      end
    end
  end
end
