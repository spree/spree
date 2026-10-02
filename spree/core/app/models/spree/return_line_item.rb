module Spree
  # One line on a {Spree::Return} — a quantity of a fulfilled item coming back.
  #
  # Named for {Spree::LineItem}, which it mirrors: `quantity` is what the
  # customer said was coming, `received_quantity` what the warehouse counted.
  # Like a line item it carries its worth before tax in `pre_tax_amount` and
  # the tax on it beside that, both for the announced quantity.
  class ReturnLineItem < Spree.base_class
    include Spree::PostSale::TaxedLine

    has_prefix_id :rli

    belongs_to :return, class_name: 'Spree::Return', inverse_of: :return_line_items
    belongs_to :fulfillment_item, class_name: 'Spree::FulfillmentItem'
    belongs_to :line_item, class_name: 'Spree::LineItem'
    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'

    validates :quantity, numericality: { greater_than: 0 }
    validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }
    validates :pre_tax_amount, numericality: { greater_than_or_equal_to: 0 }

    before_validation :set_defaults_from_line_item, on: :create

    delegate :order, :currency, to: :return

    extend Spree::DisplayMoney
    money_methods :pre_tax_amount, :included_tax_total, :additional_tax_total, :tax_total,
                  :refund_amount, :refund_tax_amount

    # What this line refunds, tax included. Once the warehouse has counted,
    # only the units that arrived are paid for — a customer who announced
    # three and sent two is owed two — and before the count there is nothing
    # to go on but the announced quantity.
    #
    # Rounded to the currency, because this is the ceiling a refund is checked
    # against as well as the figure the dialog offers: a third of $29.99 taken
    # three times is not $29.99 until it is.
    #
    # A line opened before returns carried tax holds the price it was opened
    # with in `pre_tax_amount` and no tax, so it refunds exactly what it did.
    #
    # @return [BigDecimal]
    def refund_amount
      counted_share(total)
    end

    # @return [BigDecimal] the tax inside {#refund_amount}
    def refund_tax_amount
      counted_share(tax_total)
    end

    # @return [BigDecimal] the announced units, tax included
    def total
      pre_tax_amount + tax_total
    end

    def tax_total
      included_tax_total + additional_tax_total
    end

    # The units this line gives back: none once the return is canceled, what
    # arrived once the warehouse has counted, what was announced before.
    #
    # @return [Integer]
    def credited_quantity
      return 0 if self.return.canceled?

      self.return.counted? ? received_quantity.to_i : quantity.to_i
    end

    # @return [BigDecimal] what the credited units are worth, tax included
    def credited_worth
      refund_amount
    end

    # Copies the credit rows written at opening onto the line. The before-tax
    # figure is what was paid after discounts less the tax inside it, so the
    # three columns add up to the cent.
    #
    # @return [void]
    def fold_tax_lines!
      included, additional = tax_totals_from(tax_lines.credits.reload)

      update_columns(
        pre_tax_amount: default_pre_tax_amount - included,
        included_tax_total: included,
        additional_tax_total: additional
      )
    end

    private

    def counted_share(value)
      return value unless self.return.counted?
      return 0.to_d if quantity.to_i.zero?

      Spree::Money::Rounding.to_currency((value / quantity) * received_quantity.to_i, currency)
    end

    # The refundable amount defaults to this item's share of what the
    # customer actually paid for the line, after discounts — refunding the
    # list price would give back more than was taken.
    def set_defaults_from_line_item
      self.variant ||= line_item&.variant
      self.pre_tax_amount = default_pre_tax_amount if pre_tax_amount.blank? || pre_tax_amount.zero?
    end

    def default_pre_tax_amount
      line_item&.discounted_amount_for(quantity) || 0
    end
  end
end
