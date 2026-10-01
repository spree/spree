module Spree
  # One problem item on a {Spree::Claim}, and how it is being made right:
  # money back, a replacement, or both.
  class ClaimLineItem < Spree.base_class
    include Spree::PostSale::TaxedLine

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

    extend Spree::DisplayMoney
    money_methods :refund_amount, :paid_amount, :pre_tax_amount, :included_tax_total,
                  :additional_tax_total, :tax_total

    # What the customer paid for the affected units, after discounts and with
    # the tax charged on top of the price — the ceiling for a refund on this
    # line, which is entered tax included. A claim opened before claims
    # carried tax has none, so its ceiling is unchanged.
    #
    # @return [BigDecimal]
    def paid_amount
      discounted_amount + additional_tax_total
    end

    # @return [BigDecimal] the affected units before tax
    def pre_tax_amount
      discounted_amount - included_tax_total
    end

    def tax_total
      included_tax_total + additional_tax_total
    end

    # Nothing is given back on a claim that was denied or withdrawn.
    #
    # @return [Integer]
    def credited_quantity
      claim.denied? || claim.canceled? ? 0 : quantity.to_i
    end

    # @return [BigDecimal]
    def credited_worth
      paid_amount
    end

    # @return [void]
    def fold_tax_lines!
      included, additional = tax_totals_from(tax_lines.credits.reload)
      update_columns(included_tax_total: included, additional_tax_total: additional)
    end

    # What actually ships when the claim is resolved with a replacement.
    def variant_to_send
      replacement_variant || variant
    end

    private

    def discounted_amount
      line_item&.discounted_amount_for(quantity) || 0
    end

    def set_variant_from_line_item
      self.variant ||= line_item&.variant
    end
  end
end
