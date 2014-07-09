module Spree
  # Manage (recalculate) item (LineItem or Shipment) adjustments
  class ItemAdjustments
    include ActiveSupport::Callbacks
    define_callbacks :promo_adjustments, :tax_adjustments
    attr_reader :item

    delegate :adjustments, :order, to: :item

    def initialize(item)
      @item = item
      # Don't attempt to reload the item from the DB if it's not there
      @item.reload if @item.persisted?
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
      # 
      # Tax adjustments come in not one but *two* exciting flavours:
      # Included & additional

      # Included tax adjustments are those which are included in the price.
      # These ones should not effect the eventual total price.
      #
      # Additional tax adjustments are the opposite; effecting the final total.
      promo_total = 0
      run_callbacks :promo_adjustments do
        promotion_total = adjustments.promotion.reload.map(&:update!).compact.sum
        unless promotion_total == 0
          choose_best_promotion_adjustment
        end
        promo_total = best_promotion_adjustment.try(:amount).to_f
      end

      included_tax_total = 0
      additional_tax_total = 0
      run_callbacks :tax_adjustments do
        included_tax_total = adjustments.tax.included.reload.map(&:update!).compact.sum
        additional_tax_total = adjustments.tax.additional.reload.map(&:update!).compact.sum
      end

      item.update_columns(
        :promo_total => promo_total,
        :included_tax_total => included_tax_total,
        :additional_tax_total => additional_tax_total,
        :adjustment_total => promo_total + additional_tax_total,
        :updated_at => Time.now,
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
      @best_promotion_adjustment ||= adjustments.promotion.eligible.reorder("amount ASC, created_at DESC, id DESC").first
    end
  end
end
