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
        estimate_packages(allocated_packages)
      end

      # Where each unit comes from, without quoting a rate, so a caller that
      # only needs the origins — a checkout hold — never costs a carrier request.
      #
      # @param stock_locations [Array<Spree::StockLocation>] candidate origins, preferred first
      # @return [Array<Spree::Stock::Package>]
      def allocated_packages(stock_locations = candidate_stock_locations)
        prioritize_packages(build_packages(stock_locations: stock_locations))
      end

      # @param packages [Array<Spree::Stock::Package>]
      # @return [Array<Spree::Stock::Package>] the same packages, with their delivery rates
      def estimate_packages(packages)
        packages.each do |package|
          package.delivery_rates = estimator.delivery_rates(package)
        end
        packages
      end

      # Active locations stocking any requested variant, in database order.
      #
      # @return [Array<Spree::StockLocation>]
      def candidate_stock_locations
        order.store.stock_locations.active.joins(:stock_levels)
             .where(Spree::StockLevel.table_name => { variant_id: requested_variant_ids }).distinct.to_a
      end

      def build_packages(packages = [], stock_locations: candidate_stock_locations)
        stock_levels = Packer.stock_levels_by_location(stock_locations, requested_variant_ids)

        stock_locations.each do |stock_location|
          units = allocatable_units_for(stock_location)
          next if units.empty?

          packer = build_packer(stock_location, units, stock_levels: stock_levels.fetch(stock_location.id, {}))
          packages += packer.packages
        end

        packages
      end

      private

      # An item may only be allocated from locations its delivery profile
      # covers — a profile narrowed to the cold-storage warehouse never packs
      # from anywhere else — intersected with the channel's served set when
      # the order carries one (docs/plans/6.0-channel-delivery.md). Profiles
      # resolve once per variant, not per unit.
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
        variant = unit.variant
        # The variant's own override, read raw, so variants that inherit the
        # product's profile share one slot instead of resolving it each.
        key = [variant.product_id, variant[:delivery_profile_id]]
        return @unit_profiles[key] if @unit_profiles.key?(key)

        profile = variant.resolved_delivery_profile
        profile&.delivery_origin_groups&.each(&:member_stock_location_ids)
        @unit_profiles[key] = profile
      end

      def requested_variant_ids
        inventory_units.map(&:variant_id).uniq
      end

      def prioritize_packages(packages)
        prioritizer = Prioritizer.new(packages, estimator: estimator)
        prioritizer.prioritized_packages
      end

      # Shared between prioritization (which origins can deliver at all) and
      # the rate refresh, so both answer with the same eligibility rules.
      def estimator
        @estimator ||= Estimator.new(order)
      end

      def build_packer(stock_location, inventory_units, stock_levels: nil)
        Packer.new(stock_location, inventory_units, splitters(stock_location), owner: order, stock_levels: stock_levels)
      end

      def splitters(_stock_location)
        # extension point to return custom splitters for a location
        Spree.stock_splitters
      end
    end
  end
end
