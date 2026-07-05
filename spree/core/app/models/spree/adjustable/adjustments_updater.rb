module Spree
  module Adjustable
    class AdjustmentsUpdater
      def self.update(adjustable)
        new(adjustable).update
      end

      def initialize(adjustable)
        @adjustable = adjustable
        adjustable.reload if shipment? && adjustable && adjustable.persisted?
      end

      def update
        return unless adjustable_still_exists?

        totals = {
          non_taxable_adjustment_total: 0,
          taxable_adjustment_total: 0
        }
        non_tax_adjusters.each do |klass|
          klass.adjust(@adjustable, totals)
        end

        if tax_adjuster.present?
          # Other adjustments can change the taxable amount so we need to update it first
          update_adjustable_attributes(totals)
          tax_adjuster.adjust(@adjustable, totals)
        end

        persist_totals totals
      end

      private

      def persist_totals(totals)
        attributes = totals
        attributes[:adjustment_total] = totals[:non_taxable_adjustment_total] +
          totals[:taxable_adjustment_total] +
          totals.fetch(:additional_tax_total, 0)

        update_adjustable_attributes(attributes)
      end

      def update_adjustable_attributes(attributes)
        # Only update if attributes have changed
        current_attributes = @adjustable.attributes.slice(*attributes.keys.map(&:to_s))
        return if attributes.all? { |key, value| current_attributes[key.to_s] == value }

        attributes[:updated_at] = Time.current
        @adjustable.update_columns(attributes)
      end

      def shipment?
        @adjustable.is_a?(Shipment)
      end

      def adjusters
        Spree.adjusters
      end

      def tax_adjuster
        @tax_adjuster ||= adjusters.find { |adjuster| adjuster.name == 'Spree::Adjustable::Adjuster::Tax' }
      end

      def non_tax_adjusters
        adjusters - [tax_adjuster].compact
      end

      def adjustable_still_exists?
        @adjustable&.class&.exists?(@adjustable.id)
      end
    end
  end
end
