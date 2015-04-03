require_dependency 'spree/calculator'

module Spree
  class Calculator::DefaultTax < Calculator
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

      round_to_two_places(line_items_total * rate.amount)
    end

    # When it comes to computing shipments or line items: same same.
    def compute_shipment_or_line_item(item)
      round_to_two_places(item.discounted_amount * rate.amount)
    end

    alias_method :compute_shipment, :compute_shipment_or_line_item
    alias_method :compute_line_item, :compute_shipment_or_line_item

    def compute_shipping_rate(shipping_rate)
      round_to_two_places(shipping_rate.cost * rate.amount)
    end

    private

    def rate
      self.calculable
    end

    def round_to_two_places(amount)
      BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end
  end
end
