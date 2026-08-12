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
          units = allocatable_units_for(stock_location)
          next if units.empty?

          packer = build_packer(stock_location, units)
          packages += packer.packages
        end

        packages
      end

      private

      def stock_locations_with_requested_variants
        order.store.stock_locations.active.joins(:stock_items).
          where(spree_stock_items: { variant_id: requested_variant_ids }).distinct
      end

      # An item may only be allocated from locations its delivery profile
      # covers — a profile narrowed to the cold-storage warehouse never packs
      # from anywhere else — intersected with the channel's served set when
      # the order carries one (docs/plans/6.0-channel-delivery.md). Profiles
      # resolve once per order, not per unit.
      def allocatable_units_for(stock_location)
        return [] unless channel_serves?(stock_location)

        inventory_units.select do |unit|
          profile = profile_for(unit)
          profile.nil? || profile.covers_location?(stock_location)
        end
      end

      # A nil channel means unrestricted — key-bound storefront traffic
      # always has one, but admin-created and legacy carts may not.
      def channel_serves?(stock_location)
        return true if order_channel.nil?

        order_channel.serves_location?(stock_location)
      end

      # Memoized so the channel's membership is read once per allocation, not
      # once per candidate location.
      def order_channel
        return @order_channel if defined?(@order_channel)

        @order_channel = order.try(:channel)
      end

      # Allocation asks every profile about every candidate location, so the
      # groups and their membership are loaded once with the profile rather
      # than re-queried per question.
      def profile_for(unit)
        @unit_profiles ||= {}
        product = unit.variant.product
        return @unit_profiles[product.id] if @unit_profiles.key?(product.id)

        profile = product.resolved_delivery_profile
        profile&.delivery_origin_groups&.each(&:member_stock_location_ids)
        @unit_profiles[product.id] = profile
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
