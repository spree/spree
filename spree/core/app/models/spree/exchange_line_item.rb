module Spree
  # One swap on a {Spree::Exchange}: a quantity of one variant going back,
  # the same quantity of another coming out.
  class ExchangeLineItem < Spree.base_class
    has_prefix_id :eli

    belongs_to :exchange, class_name: 'Spree::Exchange', inverse_of: :exchange_line_items
    belongs_to :fulfillment_item, class_name: 'Spree::FulfillmentItem'
    belongs_to :line_item, class_name: 'Spree::LineItem'
    belongs_to :original_variant, -> { with_deleted }, class_name: 'Spree::Variant'
    belongs_to :new_variant, -> { with_deleted }, class_name: 'Spree::Variant'

    validates :fulfillment_item, :line_item, :original_variant, :new_variant, presence: true
    validates :quantity, numericality: { greater_than: 0 }
    validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }

    validate :replacement_must_differ

    before_validation :set_original_variant_from_line_item, on: :create

    delegate :order, :currency, to: :exchange

    # What the customer paid for the units coming back, after discounts —
    # not the list price, which would over-credit a discounted line.
    def original_price
      return 0 if line_item.nil? || line_item.quantity.to_i.zero?

      (line_item.amount / line_item.quantity) * quantity.to_i
    end

    def new_variant_price
      new_variant.price_in(currency)&.amount.to_d * quantity.to_i
    end

    def price_difference
      new_variant_price - original_price
    end

    private

    def set_original_variant_from_line_item
      self.original_variant ||= line_item&.variant
    end

    # Swapping a variant for itself is a return, not an exchange.
    def replacement_must_differ
      return if original_variant_id.blank? || new_variant_id.blank?
      return if original_variant_id != new_variant_id

      errors.add(:new_variant, :must_differ_from_original)
    end
  end
end
