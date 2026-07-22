module Spree
  # Where a discount actually landed, line by line: a strictly negative amount
  # attached to a single line item or fulfillment. Promotion-backed rows are
  # created by PromotionAction#perform and maintained by Adjusters::Promotion;
  # manual rows (promotion_action_id: nil) are never touched by the adjuster.
  #
  # Named DiscountLine, not Discount — "discounts" is the applied-promotions
  # surface backed by OrderPromotion (see docs/plans/6.0-split-adjustments.md,
  # Resolved Question 10).
  class DiscountLine < Spree.base_class
    include Spree::AdjustmentLine

    has_prefix_id :dl

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :discount_lines
    belongs_to :promotion_action, -> { with_deleted }, class_name: 'Spree::PromotionAction', optional: true
    belongs_to :promotion, class_name: 'Spree::Promotion', optional: true

    # A discount is strictly a credit — zero results are never written;
    # positive manual charges are Fees.
    validates :amount, numericality: { less_than: 0 }

    scope :automatic, -> { joins(:promotion).merge(Spree::Promotion.automatic) }
    scope :manual, -> { where(promotion_action_id: nil) }
    scope :from_promotions, -> { where.not(promotion_action_id: nil) }

    def promotion?
      promotion_action.present?
    end

    def manual?
      !promotion?
    end
  end
end
