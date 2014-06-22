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

    def calculate_adjustments
      calculate_promo_total
      calculate_tax_total

      item.adjustment_total = item.promo_total + item.additional_tax_total
    end

    def calculate_promo_total
      promo_total = 0
      run_callbacks :promo_adjustments do
        promo_total = calculate(promo_adjustments)
        unless promo_total == 0
          choose_best_promotion_adjustment
          item.promo_total = best_promotion_adjustment.amount.to_f
        end
      end
    end

    def calculate_tax_total
      included_tax_total = 0
      additional_tax_total = 0
      run_callbacks :tax_adjustments do
        item.included_tax_total = calculate(included_tax_adjustments)
        item.additional_tax_total = calculate(additional_tax_adjustments)
      end
    end

    # Picks one (and only one) promotion to be eligible for this order
    # This promotion provides the most discount, and if two promotions
    # have the same amount, then it will pick the latest one.
    def choose_best_promotion_adjustment
      if best_promotion_adjustment
        other_promotions = promo_adjustments.select do |adjustment|
          adjustment != best_promotion_adjustment
        end

        other_promotions.each { |adjustment| adjustment.eligible = false }
      end
    end

    def best_promotion_adjustment
      eligible_promo_adjustments = promo_adjustments.select(&:eligible?).sort! do |adjustment1, adjustment2|
        adjustment1.amount <=> adjustment2.amount
      end

      @best_promotion_adjustment ||= eligible_promo_adjustments.first
      # TODO: Is it necessary to sort by created_at as well? Like this?
      # @best_promotion_adjustment ||= adjustments.promotion.eligible.reorder("amount ASC, created_at DESC").first
    end

    private

    def promo_adjustments
      @promo_adjustments ||= item.adjustments.select(&:promotion?)
    end

    def included_tax_adjustments
      @included_tax_adjustments ||= item.adjustments.select(&:included_tax?)
    end

    def additional_tax_adjustments
      @additional_tax_adjustments ||= item.adjustments.select(&:additional_tax?)
    end

    def calculate(adjustments)
      adjustments.map(&:update!).compact.inject(&:+).to_f
    end
  end
end
