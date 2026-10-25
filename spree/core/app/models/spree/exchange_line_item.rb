module Spree
  # One swap on a {Spree::Exchange}: a quantity of one variant going back,
  # the same quantity of another coming out.
  #
  # Both halves are taxed: the units coming back are credited the tax the
  # customer paid on them (`original_*`), and the replacement is taxed as a new
  # sale (`new_*`), each for the announced quantity.
  class ExchangeLineItem < Spree.base_class
    include Spree::PostSale::TaxedLine

    has_prefix_id :eli

    belongs_to :exchange, class_name: 'Spree::Exchange', inverse_of: :exchange_line_items
    belongs_to :fulfillment_item, class_name: 'Spree::FulfillmentItem'
    belongs_to :line_item, class_name: 'Spree::LineItem'
    belongs_to :original_variant, -> { with_deleted }, class_name: 'Spree::Variant'
    belongs_to :new_variant, -> { with_deleted }, class_name: 'Spree::Variant'

    validates :quantity, numericality: { greater_than: 0 }
    validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }

    validate :replacement_must_differ

    before_validation :set_original_variant_from_line_item, on: :create

    delegate :order, :currency, to: :exchange

    extend Spree::DisplayMoney
    money_methods :original_price, :new_variant_price, :price_difference, :original_tax_total, :new_tax_total

    # What the customer paid for the units coming back, after discounts and
    # with the tax charged on top — not the list price, which would
    # over-credit a discounted line.
    def original_price
      original_amount_for(quantity) + original_additional_tax_total
    end

    def original_pre_tax_amount
      original_amount_for(quantity) - original_included_tax_total
    end

    def original_tax_total
      original_included_tax_total + original_additional_tax_total
    end

    # What the replacement costs, tax on top included.
    def new_variant_price
      replacement_amount_for(quantity) + new_additional_tax_total
    end

    def new_pre_tax_amount
      replacement_amount_for(quantity) - new_included_tax_total
    end

    def new_tax_total
      new_included_tax_total + new_additional_tax_total
    end

    def price_difference
      new_variant_price - original_price
    end

    # The replacement keeps the deal the customer had on what it replaces:
    # its price carries the original line's discount in the same proportion,
    # so swapping a size of a discounted item costs nothing.
    #
    # @param units [Integer]
    # @return [BigDecimal]
    def replacement_amount_for(units)
      price = new_variant&.price_in(currency)&.amount.to_d

      Spree::Money::Rounding.to_currency(price * units.to_i * discount_ratio, currency)
    end

    # The units this swap covers: none once canceled, what arrived once the
    # warehouse has counted, what was announced before.
    #
    # @return [Integer]
    def credited_quantity
      return 0 if exchange.canceled?

      exchange.received? || exchange.fulfilled? ? received_quantity.to_i : quantity.to_i
    end

    # @return [BigDecimal] what the units coming back are worth, tax included
    def credited_worth
      units = credited_quantity
      return 0.to_d if quantity.to_i.zero?

      original_amount_for(units) +
        Spree::Money::Rounding.to_currency((original_additional_tax_total / quantity) * units, currency)
    end

    # What the provider taxes the replacement on (see
    # Spree::TaxProvider::Base#estimate_replacement).
    def taxable_basis
      replacement_amount_for(credited_quantity)
    end

    def tax_category_id
      new_variant&.tax_category_id
    end

    # What the units that arrived are credited, from the rows as they stand.
    #
    # @return [BigDecimal]
    def settled_credit
      original_amount_for(received_quantity) + tax_lines.credits.additional.sum(:amount)
    end

    # What their replacements cost, from the rows as they stand.
    #
    # @return [BigDecimal]
    def settled_charge
      replacement_amount_for(received_quantity) + tax_lines.charges.additional.sum(:amount)
    end

    # The tax inside {#settled_credit} less the tax inside {#settled_charge}.
    #
    # @return [BigDecimal]
    def settled_tax
      credited_tax_total - tax_lines.charges.sum(:amount)
    end

    # @return [void]
    def fold_tax_lines!
      rows = tax_lines.reload.to_a
      original_included, original_additional = tax_totals_from(rows.select(&:credit?))
      new_included, new_additional = tax_totals_from(rows.reject(&:credit?))

      update_columns(
        original_included_tax_total: original_included,
        original_additional_tax_total: original_additional,
        new_included_tax_total: new_included,
        new_additional_tax_total: new_additional
      )
    end

    private

    def original_amount_for(units)
      line_item&.discounted_amount_for(units) || 0.to_d
    end

    def discount_ratio
      amount = line_item&.amount.to_d
      return 1 unless amount.positive?

      [line_item.discounted_amount, 0].max / amount
    end

    def recorded_tax_total
      original_tax_total + new_tax_total
    end

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
