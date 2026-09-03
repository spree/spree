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
      # The part of the weight that scales with cartons rather than units —
      # the declared gross where the merchant recorded one, else the empty
      # carton's own weight. Carried for the same reason as the divisors: it
      # is what lets two part-full cartons collapse into one without keeping
      # both packagings' weight.
      attribute :weight_per_carton, :decimal
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
          weight_per_carton: weight_per_carton_for(variant),
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
          weight_per_carton: (weight_per_carton_for(variant) if cartons),
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
        recombined = divide(units, first.units_per_carton)
        cartons = recombined || parts.filter_map(&:cartons).sum.presence
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
          # Volume follows the recombined carton count for the same reason
          # the count itself does: adding two part-full cartons' volumes
          # reports space the combined shipment does not take.
          volume: combined_volume(parts, recombined),
          weight: combined_weight(parts, cartons),
          weight_per_carton: parts.filter_map(&:weight_per_carton).first,
          complete: parts.all?(&:complete?)
        )
      end

      # Goods weight scales with units, so summing the parts is right for it;
      # the packaging scales with cartons, so each carton the merge collapses
      # must give its share back — otherwise two part-full cartons folded into
      # one keep both packagings' weight. A snapshot frozen before the
      # component was recorded has nil here and keeps the plain sum.
      def self.combined_weight(parts, cartons)
        summed = parts.sum(&:weight)
        per_carton = parts.filter_map(&:weight_per_carton).first
        return summed if cartons.nil? || per_carton.nil?

        collapsed = parts.filter_map(&:cartons).sum - cartons
        return summed unless collapsed.positive?

        summed - (per_carton * collapsed)
      end
      private_class_method :combined_weight

      # Per-carton volume from whichever part recorded one, scaled to the
      # combined count. Falls back to the plain sum for lines measured loose,
      # where volume is per unit and adding is right.
      def self.combined_volume(parts, cartons)
        summed = parts.sum(&:volume)
        return summed if cartons.nil?

        measured = parts.detect { |part| part.complete? && part.cartons.to_i.positive? && part.volume.to_d.positive? }
        return summed if measured.nil?

        (measured.volume.to_d / measured.cartons) * cartons
      end
      private_class_method :combined_volume

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
      # one — that figure already includes the box. Otherwise the goods plus
      # the empty carton's own weight, so the packaging is not simply lost
      # from a shipment the summary calls fully measured.
      def self.carton_weight_for(variant, cartons, quantity)
        declared = Spree::Measurement.to_kilograms(variant.carton_weight, unit: variant.weight_unit)
        return declared * cartons if declared&.positive?

        (unit_weight(variant) * quantity) + (carton_tare(variant) * cartons)
      end
      private_class_method :carton_weight_for

      # The carton-scaling component of this variant's weight: the declared
      # gross when one is recorded (it counts per carton, goods included),
      # else the empty carton's own weight (the goods then count per unit).
      def self.weight_per_carton_for(variant)
        declared = Spree::Measurement.to_kilograms(variant.carton_weight, unit: variant.weight_unit)
        return declared if declared&.positive?

        carton_tare(variant)
      end
      private_class_method :weight_per_carton_for

      # The empty carton's own weight, in the kilograms the summary reports.
      def self.carton_tare(variant)
        Spree::Measurement.to_kilograms(
          variant.carton_package_type&.weight, unit: variant.carton_package_type&.weight_unit
        ) || 0
      end
      private_class_method :carton_tare

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
          'weight_per_carton' => weight_per_carton && BigDecimal(weight_per_carton.to_s).to_s('F'),
          'volume' => BigDecimal(volume.to_s).to_s('F'),
          'weight' => BigDecimal(weight.to_s).to_s('F'),
          'complete' => complete
        )
      end
    end
  end
end
