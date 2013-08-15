module Spree
  # Manage (recalculate) item (LineItem or Shipment) adjustments
  class ItemAdjustments
    attr_reader :item

    delegate :adjustments, :order, to: :item

    def initialize(item)
      @item = item
    end

    def update
      update_adjustments if item.persisted?
      item
    end

    def update_adjustments
      adjustment_total = adjustments.map(&:update!).compact.sum
      choose_best_promotion_adjustment

      item.update_column(:adjustment_total, adjustment_total)
    end

    # Picks one (and only one) promotion to be eligible for this order
    # This promotion provides the most discount, and if two promotions
    # have the same amount, then it will pick the latest one.
    def choose_best_promotion_adjustment
      if best_promotion_adjustment = self.adjustments.promotion.eligible.reorder("amount ASC, created_at DESC").first
        other_promotions = self.adjustments.promotion.where("id NOT IN (?)", best_promotion_adjustment.id)
        other_promotions.update_all(:eligible => false)
      end
    end
  end
end
