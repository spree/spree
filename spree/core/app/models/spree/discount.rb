module Spree
  # A promotion or manual discount on a line item or fulfillment. Amount is
  # enforced non-positive (validation + DB CHECK). Provenance snapshots
  # (+code+, +value+, +value_type+) keep rows meaningful after the promotion
  # is deleted — the promotion FKs are nullified, never cascaded.
  #
  # Order-level discounts are distributed proportionally across line items at
  # application time (largest-remainder) — there are no order-attached rows.
  class Discount < Spree.base_class
    include Spree::TypedAdjustmentLine

    has_prefix_id :disc

    # Source — nullified on promotion deletion
    belongs_to :promotion_action, class_name: 'Spree::PromotionAction', optional: true
    belongs_to :promotion, class_name: 'Spree::Promotion', optional: true

    # Adjustable — exactly one
    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true

    validates :amount, numericality: { less_than_or_equal_to: 0 }
    validates :kind, presence: true
    validate :exactly_one_adjustable

    scope :for_line_items, -> { where.not(line_item_id: nil) }
    scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }
    scope :promotion, -> { where(kind: 'promotion') }
    scope :manual, -> { where(kind: 'manual') }
    scope :nonzero, -> { where.not(amount: 0) }

    # @return [Spree::LineItem, Spree::Fulfillment, nil]
    def adjustable
      line_item || fulfillment
    end

    def promotion?
      kind == 'promotion'
    end

    private

    def exactly_one_adjustable
      errors.add(:base, :exactly_one_adjustable, message: Spree.t('errors.messages.exactly_one_adjustable')) unless [line_item, fulfillment].compact.one?
    end
  end
end
