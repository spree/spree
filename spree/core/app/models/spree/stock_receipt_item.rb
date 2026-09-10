module Spree
  # One line of a delivery: how many of a document's line arrived, how many of
  # those were refused, and why. Accepted units reach the shelf; rejected ones
  # exist only here.
  class StockReceiptItem < Spree.base_class
    has_prefix_id :sri

    REJECTION_REASONS = %w[damaged wrong_item expired other].freeze

    belongs_to :stock_receipt, class_name: 'Spree::StockReceipt', inverse_of: :items
    # A purchase order item or a stock transfer item.
    belongs_to :line, polymorphic: true, inverse_of: :stock_receipt_items

    validates :quantity_accepted, :quantity_rejected,
              numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :rejection_reason, inclusion: { in: REJECTION_REASONS },
                                 if: -> { quantity_rejected.to_i.positive? }
    validate :counts_something

    delegate :variant, :variant_name, :variant_sku, to: :line, allow_nil: true

    # @return [Integer] everything the dock counted, accepted or not
    def quantity_counted
      quantity_accepted.to_i + quantity_rejected.to_i
    end

    private

    def counts_something
      return if quantity_counted.positive?

      errors.add(:base, :nothing_counted, message: Spree.t('stock_receipt.errors.nothing_counted'))
    end
  end
end
