require_dependency 'spree/calculator'

module Spree
  class Calculator::DefaultTax < Calculator
    include Spree::VatPriceCalculation
    def self.description
      Spree.t(:default_tax)
    end

    # Default tax calculator still needs to support orders for legacy reasons
    # Orders created before Spree 2.1 had tax adjustments applied to the order, as a whole.
    # Orders created with Spree 2.2 and after, have them applied to the line items individually.
    def compute_order(order)
      matched_line_items = order.line_items.select do |line_item|
        line_item.tax_category == rate.tax_category
      end

      line_items_total = matched_line_items.sum(&:total)
      if rate.included_in_price
        round_to_two_places(line_items_total - (line_items_total / (1 + rate.amount)))
      else
        round_to_two_places(line_items_total * rate.amount)
      end
    end

    # When it comes to computing shipments or line items: same same.
    #
    # Both tax modes are computed from the item's live taxable basis, which
    # follows every discount: item-level promotions and the item's share of
    # whole-order promotions (see LineItem#taxable_basis). Included
    # (VAT-style) tax intentionally does not read the stored pre_tax_amount
    # column — that column is only refreshed by Spree::TaxRate.adjust on
    # checkout transitions, so it goes stale the moment a promotion is
    # applied or removed.
    def compute_shipment_or_line_item(item)
      basis = item.taxable_basis

      if rate.included_in_price
        deduced_total_by_rate(net_basis(item, basis), rate)
      else
        round_to_two_places(basis * rate.amount)
      end
    end

    alias compute_shipment compute_shipment_or_line_item
    alias compute_line_item compute_shipment_or_line_item

    def compute_shipping_rate(shipping_rate)
      if rate.included_in_price
        pre_tax_amount = shipping_rate.cost / (1 + rate.amount)
        deduced_total_by_rate(pre_tax_amount, rate)
      else
        with_tax_amount = shipping_rate.cost * rate.amount
        round_to_two_places(with_tax_amount)
      end
    end

    private

    def rate
      calculable
    end

    def deduced_total_by_rate(pre_tax_amount, rate)
      round_to_two_places(pre_tax_amount * rate.amount)
    end

    # Backs all included-in-price rates out of the gross basis, mirroring
    # Spree::TaxRate.store_pre_tax_amount (several rates can share a tax
    # category, e.g. MOSS VAT). Falls back to this rate's amount when no
    # rate matches the item, e.g. in bare setups without matching zones.
    def net_basis(item, basis)
      included = included_rates_amount(item)
      included = rate.amount if included.zero?

      basis / (1 + included)
    end

    def included_rates_amount(item)
      Spree::TaxRate.included_tax_amount_for(tax_zone: rate.zone, tax_category: item.tax_category)
    end
  end
end
