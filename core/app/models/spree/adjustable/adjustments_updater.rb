module Spree
  module Adjustable
    class AdjustmentsUpdater
      def self.update(adjustable)
        new(adjustable).update
      end

      def initialize(adjustable)
        @adjustable = adjustable
        adjustable.reload if shipment? && persisted?
        PromotionAccumulator.add_to(adjustable)
      end

      def update
        return unless persisted?
        update_promo_adjustments
        update_tax_adjustments
        persist_totals
      end

      private

      attr_reader :adjustable
      delegate :adjustments, :persisted?, to: :adjustable

      def update_promo_adjustments
        adjustments.promotion.reload.each { |a| a.update!(adjustable) }
        @promo_total = PromotionSelector.select!(adjustable)
      end

      def update_tax_adjustments
        tax = (adjustable.try(:all_adjustments) || adjustments).tax
        @included_tax_total = tax.is_included.reload.map(&:update!).compact.sum
        @additional_tax_total = tax.additional.reload.map(&:update!).compact.sum
      end

      def persist_totals
        adjustable.update_columns(
          promo_total: @promo_total,
          included_tax_total: @included_tax_total,
          additional_tax_total: @additional_tax_total,
          adjustment_total: @promo_total + @additional_tax_total,
          updated_at: Time.now
        )
      end

      def shipment?
        adjustable.is_a?(Shipment)
      end
    end
  end
end
