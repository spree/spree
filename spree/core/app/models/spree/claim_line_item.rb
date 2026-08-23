module Spree
  # One problem item on a {Spree::Claim}, and how it is being made right:
  # money back, a replacement, or both.
  class ClaimLineItem < Spree.base_class
    has_prefix_id :cli

    belongs_to :claim, class_name: 'Spree::Claim', inverse_of: :claim_line_items
    belongs_to :line_item, class_name: 'Spree::LineItem'
    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    # Nil means "send the same thing again"; a different variant swaps it.
    belongs_to :replacement_variant, -> { with_deleted }, class_name: 'Spree::Variant', optional: true

    # Photographic evidence of damage, supplied by the customer.
    has_many_attached :images

    validates :quantity, numericality: { greater_than: 0 }
    validates :refund_amount, numericality: { greater_than_or_equal_to: 0 }

    before_validation :set_variant_from_line_item, on: :create

    delegate :order, :currency, to: :claim

    # What the customer paid for the affected units, after discounts — the
    # ceiling for a refund on this line.
    def paid_amount
      return 0 if line_item.nil? || line_item.quantity.to_i.zero?

      (line_item.amount / line_item.quantity) * quantity.to_i
    end

    def display_refund_amount
      Spree::Money.new(refund_amount, currency: currency)
    end

    # What actually ships when the claim is resolved with a replacement.
    def variant_to_send
      replacement_variant || variant
    end

    private

    def set_variant_from_line_item
      self.variant ||= line_item&.variant
    end
  end
end
