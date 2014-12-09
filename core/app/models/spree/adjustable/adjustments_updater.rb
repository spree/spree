module Spree
  class ItemAdjustments

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
      promo_adjustments = adjustments.promotion.reload.map { |a| a.update!(adjustable) }
      promotion_total = promo_adjustments.compact.sum
      choose_best_promotion_adjustment unless promotion_total == 0
      @promo_total = best_promotion_adjustment.try(:amount).to_f
    end

    def update_tax_adjustments
      tax = (adjustable.try(:all_adjustments) || adjustable.adjustments).tax
      @included_tax_total = tax.included.reload.map(&:update!).compact.sum
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

    # Picks one (and only one) promotion to be eligible for this order
    # This promotion provides the most discount, and if two promotions
    # have the same amount, then it will pick the latest one.
    def choose_best_promotion_adjustment
      if best_promotion_adjustment
        other_promotions = self.adjustments.promotion.where.not(id: best_promotion_adjustment.id)
        other_promotions.update_all(:eligible => false)
      end
    end

    def best_promotion_adjustment
      @best_promotion_adjustment ||= adjustments.promotion.eligible.reorder("amount ASC, created_at DESC, id DESC").first
    end
  end
end
