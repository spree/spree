module Spree
  # A line on a purchase order or a stock transfer: one variant, a promised
  # quantity, and the running totals of what deliveries have brought.
  module ReceivableItem
    extend ActiveSupport::Concern

    class_methods do
      # Names the column holding what the line promised: `quantity_ordered` on
      # a purchase order line, `quantity_shipped` on a transfer line.
      def expects_quantity_in(attribute)
        class_attribute :expected_quantity_attribute, default: attribute.to_sym,
                                                      instance_writer: false
      end
    end

    included do
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
      has_many :stock_receipt_items, as: :line, class_name: 'Spree::StockReceiptItem',
                                     inverse_of: :line, dependent: :destroy

      validates :quantity_received, :quantity_rejected, numericality: {
        greater_than_or_equal_to: 0, only_integer: true
      }

      delegate :name, :sku, to: :variant, prefix: true, allow_nil: true
    end

    # How many units this line promised.
    #
    # @return [Integer]
    def quantity_expected
      public_send(self.class.expected_quantity_attribute).to_i
    end

    # The image for this line: the variant's own, or its product's when the
    # variant has none — the same fallback a line item on an order uses.
    #
    # @return [Spree::Media, nil]
    def thumbnail
      variant&.primary_media || variant&.product&.primary_media
    end

    # Units that count against the promise. A supplier's promise is met by
    # units the dock accepts — refused goods go back and are still owed. A
    # transfer overrides this: its promise is met by units that arrived at
    # all, since the damaged ones are not in the van any more.
    #
    # @return [Integer]
    def quantity_settled
      quantity_received.to_i
    end

    # Units still owed. Never below zero: anything above the promise is
    # `quantity_over`, not a negative debt.
    #
    # @return [Integer]
    def outstanding
      [quantity_expected - quantity_settled, 0].max
    end

    # Units that arrived beyond what was promised.
    #
    # @return [Integer]
    def quantity_over
      [quantity_settled - quantity_expected, 0].max
    end

    # Units still on their way. Not `outstanding`: on a purchase order settled
    # means received, so outstanding keeps counting units the dock refused,
    # and those never arrive.
    #
    # @return [Integer]
    def incoming
      [quantity_expected - quantity_received.to_i - quantity_rejected.to_i, 0].max
    end

    def under_received?
      outstanding.positive?
    end

    def over_received?
      quantity_over.positive?
    end
  end
end
