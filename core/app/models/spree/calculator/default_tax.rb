require_dependency 'spree/calculator'

module Spree
  class Calculator::DefaultTax < Calculator
    include VatPriceCalculation
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
    def compute_shipment_or_line_item(item)
      if rate.included_in_price
        deduced_total_by_rate(item.pre_tax_amount, rate)
      else
        round_to_two_places(item.discounted_amount * rate.amount)
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
  end
end
