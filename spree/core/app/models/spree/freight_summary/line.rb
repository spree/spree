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
      # The divisors behind the two counts above, carried so a summary split
      # across consignments can be recombined without consulting the catalog
      # it was frozen away from.
      attribute :units_per_carton, :integer
      attribute :cartons_per_pallet, :integer
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
        cartons = variant.cartons_for(quantity)

        new(
          **identity(variant),
          units: quantity,
          cartons: cartons,
          # A line that counts cartons still says how they stack. Leaving it
          # blank would drop the pallet count for the whole summary, not just
          # for this line.
          pallets: (pallets_for(variant, cartons) if cartons),
          volume: (unit_volume || 0) * quantity,
          # A merchant who recorded what a packed carton weighs knows more
          # than the loose goods do, even when the carton itself is
          # unmeasured — using the goods' weight there understates the load.
          weight: cartons ? carton_weight_for(variant, cartons, quantity) : unit_weight(variant) * quantity,
          complete: false
        )
      end
      private_class_method :from_units

      # Adds together the lines the same variant produced in several
      # consignments.
      #
      # Cartons and pallets are re-derived from the combined units rather than
      # summed, because each part was rounded up when it was built: a variant
      # packed twelve to a carton, split three units and nine, is one carton
      # in total and not two. The divisors ride on the line itself, so a
      # frozen snapshot can be recombined years later without asking today's
      # catalog — which is exactly what freezing it was meant to avoid.
      #
      # @param parts [Array<Spree::FreightSummary::Line>]
      # @return [Spree::FreightSummary::Line]
      def self.combine(parts)
        first = parts.first
        units = parts.sum(&:units)
        cartons = divide(units, first.units_per_carton) || parts.filter_map(&:cartons).sum.presence
        pallets = cartons && divide(cartons, first.cartons_per_pallet)

        new(
          variant_id: first.variant_id,
          sku: first.sku,
          name: first.name,
          units: units,
          units_per_carton: first.units_per_carton,
          cartons_per_pallet: first.cartons_per_pallet,
          cartons: cartons,
          pallets: pallets,
          volume: parts.sum(&:volume),
          weight: parts.sum(&:weight),
          complete: parts.all?(&:complete?)
        )
      end

      # A part of anything still ships as a whole one.
      def self.divide(quantity, divisor)
        return if divisor.to_i.zero?

        (quantity / divisor.to_f).ceil
      end
      private_class_method :divide

      def self.identity(variant)
        {
          variant_id: variant.prefixed_id,
          sku: variant.sku,
          name: variant.descriptive_name,
          units_per_carton: variant.units_per_carton,
          cartons_per_pallet: variant.cartons_per_pallet
        }
      end
      private_class_method :identity

      # Nil when the variant does not say how its cartons stack — the summary
      # then reports no pallet count at all rather than a partial one.
      def self.pallets_for(variant, cartons)
        divide(cartons, variant.cartons_per_pallet)
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

      def as_json(identify_lines: true)
        identity = identify_lines ? { 'variant_id' => variant_id, 'sku' => sku, 'name' => name } : {}

        identity.merge(
          'units' => units,
          'cartons' => cartons,
          'pallets' => pallets,
          'units_per_carton' => units_per_carton,
          'cartons_per_pallet' => cartons_per_pallet,
          'volume' => BigDecimal(volume.to_s).to_s('F'),
          'weight' => BigDecimal(weight.to_s).to_s('F'),
          'complete' => complete
        )
      end
    end
  end
end
