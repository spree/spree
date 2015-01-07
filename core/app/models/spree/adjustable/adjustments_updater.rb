module Spree
  module Adjustable
    class AdjustmentsUpdater
      def self.update(adjustable)
        new(adjustable).update
      end

      def initialize(adjustable)
        @adjustable = adjustable
        adjustable.reload if shipment? && persisted?
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
        promo_adjustments = adjustments.competing_promos.reload.map { |a| a.update!(adjustable) }
        promos_total = promo_adjustments.compact.sum
        choose_best_promo_adjustment unless promos_total == 0
        @promo_total = best_promo_adjustment.try(:amount).to_f
      end

      def update_tax_adjustments
        tax = (adjustable.try(:all_adjustments) || adjustable.adjustments).tax
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

      # Picks one (and only one) competing discount to be eligible for
      # this order. This adjustment provides the most discount, and if
      # two adjustments have the same amount, then it will pick the
      # latest one.
      def choose_best_promo_adjustment
        if best_promo_adjustment
          other_promotions = adjustments.competing_promos.where.not(id: best_promo_adjustment.id)
          other_promotions.update_all(eligible: false)
        end
      end

      def best_promo_adjustment
        @best_promo_adjustment ||= begin
          adjustments.competing_promos.eligible.reorder("amount ASC, created_at DESC, id DESC").first
        end
      end
    end
  end
end
