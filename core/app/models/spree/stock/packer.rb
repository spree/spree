module Spree
  module Stock
    class Packer
      attr_reader :stock_location, :inventory_units, :splitters, :allocated_inventory_units

      def initialize(stock_location, inventory_units, splitters=[Splitter::Base])
        @stock_location = stock_location
        @inventory_units = inventory_units
        @splitters = splitters
        @allocated_inventory_units = []
      end

      def packages
        if splitters.empty?
          [default_package]
        else
          build_splitter.split [default_package]
        end
      end

      def default_package
        package = Package.new(stock_location)

        # Group by variant_id as grouping by variant fires cached query.
        inventory_units.group_by(&:variant_id).each do |variant_id, variant_inventory_units|
          variant = Spree::Variant.find(variant_id)
          units = variant_inventory_units.clone
          if variant.should_track_inventory?
            next unless stock_location.stock_item(variant)

            on_hand, backordered = stock_location.fill_status(variant, units.size)
            on_hand_units, backordered_units = units.slice!(0, on_hand), units.slice!(0, backordered)

            package.add_multiple on_hand_units, :on_hand if on_hand > 0
            package.add_multiple backordered_units, :backordered if backordered > 0

            @allocated_inventory_units += (on_hand_units + backordered_units)
          else
            package.add_multiple units
            @allocated_inventory_units += units
          end
        end

        package
      end

      private

      def build_splitter
        splitter = nil
        splitters.reverse.each do |klass|
          splitter = klass.new(self, splitter)
        end
        splitter
      end
    end
  end
end
