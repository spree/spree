module Spree
  # An extensible charge (surcharge, handling, gift wrap, COD, payment fee).
  # May target a line item or fulfillment, or be order-level (both adjustable
  # FKs nil). Fees are taxable — the tax provider writes TaxLine rows against
  # them. Ad-hoc credits are manual Discounts, never negative fees (amount is
  # enforced non-negative by validation + DB CHECK).
  class Fee < Spree.base_class
    include Spree::TypedAdjustmentLine

    # Extensions may append their own kinds — the list is validated, not frozen.
    # `duty` rows are written by a duties provider's adjuster and snapshot the
    # classification they were calculated from in `metadata` — never re-derive
    # a duty from the live catalog.
    KINDS = %w[surcharge handling gift_wrap cod payment duty]

    has_prefix_id :fee

    # Adjustable — optional: both nil means an order-level fee
    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true

    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy

    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    validates :kind, presence: true, inclusion: { in: ->(_fee) { KINDS }, allow_blank: true }

    scope :for_line_items, -> { where.not(line_item_id: nil) }
    scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }
    scope :order_level, -> { where(line_item_id: nil, fulfillment_id: nil) }

    # @return [Spree::LineItem, Spree::Fulfillment, nil] nil for order-level fees
    def adjustable
      line_item || fulfillment
    end

    def order_level?
      line_item_id.nil? && fulfillment_id.nil?
    end
  end
end
