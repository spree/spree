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

    # TODO this should be probably the place to calculate proper item taxes
    # values after promotions are applied
    def update_adjustments
      # Reloading all adjustments as this method may be called directly after an adjustment is created.
      # For example, TaxRate#create_adjustment calls this method.
      adjustment_total = adjustments.reload.map(&:update!).compact.sum

      unless adjustment_total == 0
        adjustment_total = adjustments.tax.sum(:amount)

        if best_promotion_adjustment
          choose_best_promotion_adjustment
          adjustment_total += best_promotion_adjustment.amount
        end
      end

      item.update_column(:adjustment_total, adjustment_total)
    end

    # Picks one (and only one) promotion to be eligible for this order
    # This promotion provides the most discount, and if two promotions
    # have the same amount, then it will pick the latest one.
    def choose_best_promotion_adjustment
      if best_promotion_adjustment
        other_promotions = self.adjustments.promotion.where("id NOT IN (?)", best_promotion_adjustment.id)
        other_promotions.update_all(:eligible => false)
      end
    end

    def best_promotion_adjustment
      @best_promotion_adjustment ||= adjustments.promotion.eligible.reorder("amount ASC, created_at DESC").first
    end
  end
end
