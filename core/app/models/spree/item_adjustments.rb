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
      # Promotion adjustments must be applied first, then tax adjustments.
      # This fits the criteria for VAT tax as outlined here:
      # http://www.hmrc.gov.uk/vat/managing/charging/discounts-etc.htm#1
      #
      # It also fits the criteria for sales tax as outlined here:
      # http://www.boe.ca.gov/formspubs/pub113/
      promotion_total = adjustments.promotion.reload.map(&:update!).compact.sum
      unless promotion_total == 0
        choose_best_promotion_adjustment
      end
      promo_total = best_promotion_adjustment.try(:amount).to_f
      item.update_column(:promo_total, promo_total)

      tax_total = adjustments.tax.reload.map(&:update!).compact.sum

      item.update_columns(
        :tax_total => tax_total,
        :adjustment_total => promo_total + tax_total,
      )
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
