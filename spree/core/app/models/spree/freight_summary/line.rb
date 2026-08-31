module Spree
  class FreightSummary
    # One variant's contribution to a freight summary.
    #
    # Built once from the live catalog and thereafter carried as plain data,
    # so an order's frozen summary keeps reporting the cartons it actually
    # shipped in even after the variant is repacked.
    class Line
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :variant_id, :string
      attribute :sku, :string
      attribute :name, :string
      attribute :units, :integer, default: 0
      attribute :cartons, :integer
      attribute :pallets, :integer
      attribute :volume, :decimal, default: 0
      attribute :weight, :decimal, default: 0
      # False when the variant declares no carton, so volume and weight came
      # from unit dimensions instead.
      attribute :complete, :boolean, default: false

      # @param variant [Spree::Variant]
      # @param quantity [Integer]
      # @return [Spree::FreightSummary::Line]
      def self.build(variant, quantity)
        quantity = quantity.to_i
        cartons = variant.cartons_for(quantity)
        carton_volume = variant.carton_volume

        if cartons && carton_volume
          from_cartons(variant, quantity, cartons, carton_volume)
        else
          from_units(variant, quantity)
        end
      end

      # The measured path: the variant declares a carton with geometry, so
      # volume and weight are the cartons the order actually fills.
      def self.from_cartons(variant, quantity, cartons, carton_volume)
        new(
          **identity(variant),
          units: quantity,
          cartons: cartons,
          pallets: pallets_for(variant, cartons),
          volume: carton_volume * cartons,
          weight: carton_weight_for(variant, cartons, quantity),
          complete: true
        )
      end
      private_class_method :from_cartons

      # The fallback: no carton on the variant, so the goods are measured
      # loose. Real enough to quote against, and flagged as incomplete.
      def self.from_units(variant, quantity)
        unit_volume = Spree::Measurement.cubic_meters(
          variant.width, variant.height, variant.depth, unit: variant.dimensions_unit
        )

        new(
          **identity(variant),
          units: quantity,
          cartons: variant.cartons_for(quantity),
          volume: (unit_volume || 0) * quantity,
          weight: unit_weight(variant) * quantity,
          complete: false
        )
      end
      private_class_method :from_units

      def self.identity(variant)
        { variant_id: variant.prefixed_id, sku: variant.sku, name: variant.descriptive_name }
      end
      private_class_method :identity

      # Nil when the variant does not say how its cartons stack — the summary
      # then reports no pallet count at all rather than a partial one.
      def self.pallets_for(variant, cartons)
        return if variant.cartons_per_pallet.to_i.zero?

        (cartons / variant.cartons_per_pallet.to_f).ceil
      end
      private_class_method :pallets_for

      # A packed carton's declared gross weight where the merchant recorded
      # one; otherwise the goods' own weight, which at least counts the
      # contents.
      def self.carton_weight_for(variant, cartons, quantity)
        declared = Spree::Measurement.to_kilograms(variant.carton_weight, unit: variant.weight_unit)
        return declared * cartons if declared&.positive?

        unit_weight(variant) * quantity
      end
      private_class_method :carton_weight_for

      def self.unit_weight(variant)
        Spree::Measurement.to_kilograms(variant.weight, unit: variant.weight_unit) || 0
      end
      private_class_method :unit_weight

      # @return [Boolean]
      def cartons?
        cartons.to_i.positive?
      end

      # @return [Boolean]
      def complete?
        !!complete
      end

      def as_json(*)
        {
          'variant_id' => variant_id,
          'sku' => sku,
          'name' => name,
          'units' => units,
          'cartons' => cartons,
          'pallets' => pallets,
          'volume' => volume.to_s,
          'weight' => weight.to_s,
          'complete' => complete
        }
      end
    end
  end
end
