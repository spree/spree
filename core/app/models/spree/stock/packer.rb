module Spree
  module Stock
    class Packer
      attr_reader :stock_location, :inventory_units, :splitters

      def initialize(stock_location, inventory_units, splitters=[Splitter::Base])
        @stock_location = stock_location
        @inventory_units = inventory_units
        @splitters = splitters
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
        inventory_units.group_by(&:variant).each do |variant, variant_inventory_units|
          units = variant_inventory_units.clone
          if variant.should_track_inventory?
            next unless stock_location.stock_item(variant)

            on_hand, backordered = stock_location.fill_status(variant, units.count)
            package.add_multiple units.slice!(0, on_hand), :on_hand if on_hand > 0
            package.add_multiple units.slice!(0, backordered), :backordered if backordered > 0
          else
            package.add_multiple units
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
