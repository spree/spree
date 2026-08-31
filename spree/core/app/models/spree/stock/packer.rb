module Spree
  module Stock
    class Packer
      attr_reader :stock_location, :inventory_units, :splitters, :owner

      # @param owner [Spree::Cart, Spree::Order, nil] the purchase being
      #   packed. Every package it builds carries this, including the ones
      #   splitters derive, because a proposed package's inventory units
      #   belong to no order yet — so anything reading the buyer through the
      #   package (the packaging tare, the channel and company eligibility
      #   rules) would otherwise see nothing.
      def initialize(stock_location, inventory_units, splitters = [Splitter::Base], owner: nil)
        @stock_location = stock_location
        @inventory_units = inventory_units
        @splitters = splitters
        @owner = owner
      end

      def packages
        if splitters.empty?
          [default_package]
        else
          build_splitter.split [default_package]
        end
      end

      def default_package
        package = build_package

        # Group by variant_id as grouping by variant fires cached query.
        inventory_units.index_by(&:variant_id).each do |variant_id, inventory_unit|
          variant = Spree::Variant.find(variant_id)
          unit = inventory_unit.dup # Can be used by others, do not use directly
          if variant.should_track_inventory?
            next unless stock_location.stocks? variant

            on_hand, backordered = stock_location.fill_status(variant, unit.quantity)
            package.add(InventoryUnit.split(unit, backordered), :backordered) if backordered.positive?
            package.add(InventoryUnit.split(unit, on_hand), :on_hand) if on_hand.positive?
          else
            package.add unit
          end
        end

        package
      end

      # The single point every package this packer emits is born at, so the
      # owner cannot be lost by a splitter that builds its own.
      #
      # @return [Spree::Stock::Package]
      def build_package(contents = [])
        package = Package.new(stock_location, contents)
        package.owner = owner
        package
      end

      private

      def build_splitter
        splitter = nil
        splitters.reverse_each do |klass|
          splitter = klass.new(self, splitter)
        end
        splitter
      end
    end
  end
end
