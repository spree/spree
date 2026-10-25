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
      # Every candidate location's levels for the given variants in one query,
      # lowest id first as StockLocation#stock_level reads, for packing several
      # locations without a read per location.
      #
      # @param stock_locations [Array<Spree::StockLocation>]
      # @param variant_ids [Array]
      # @return [Hash{Integer => Hash{Integer => Spree::StockLevel}}] by location, then variant
      def self.stock_levels_by_location(stock_locations, variant_ids)
        Spree::StockLevel.where(stock_location_id: stock_locations.map(&:id), variant_id: variant_ids).
          order(:id).group_by(&:stock_location_id).
          transform_values { |levels| levels.group_by(&:variant_id).transform_values(&:first) }
      end

      # @param stock_levels [Hash{Integer => Spree::StockLevel}, nil] this
      #   location's levels by variant id, when the caller read them already
      def initialize(stock_location, inventory_units, splitters = [Splitter::Base], owner: nil, stock_levels: nil)
        @stock_location = stock_location
        @inventory_units = inventory_units
        @stock_levels = stock_levels
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
        units_by_variant_id = inventory_units.index_by(&:variant_id)
        # The package's variants and their levels here, each in one query
        # rather than one per variant. Lowest id first, as StockLocation#stock_level reads.
        variants = variants_for(units_by_variant_id)
        stock_levels = @stock_levels || stock_location.stock_levels.where(variant_id: units_by_variant_id.keys).order(:id).
                       group_by(&:variant_id).transform_values(&:first)

        units_by_variant_id.each do |variant_id, inventory_unit|
          variant = variants[variant_id] || Spree::Variant.find(variant_id)
          unit = inventory_unit.dup # Can be used by others, do not use directly
          if variant.should_track_inventory?
            stock_level = stock_levels[variant_id]
            next if stock_level.nil?

            on_hand, backordered = stock_location.fill_status(variant, unit.quantity, stock_level: stock_level)
            package.add(FulfillmentItem.split(unit, backordered), :backordered) if backordered.positive?
            package.add(FulfillmentItem.split(unit, on_hand), :on_hand) if on_hand.positive?
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

      # The units' own variants when they carry them, so a cart's variants are
      # read once however many locations are packed.
      def variants_for(units_by_variant_id)
        variants = units_by_variant_id.each_with_object({}) do |(variant_id, unit), loaded|
          loaded[variant_id] = unit.variant if unit.association(:variant).loaded?
        end
        missing_ids = units_by_variant_id.keys - variants.keys
        missing_ids.empty? ? variants : variants.merge(Spree::Variant.where(id: missing_ids).index_by(&:id))
      end

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
