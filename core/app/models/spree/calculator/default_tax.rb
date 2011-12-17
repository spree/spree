module Spree
  class Calculator::DefaultTax < Calculator
    def self.description
      I18n.t(:default_tax)
    end

    def compute(computable)
      case computable
        when Spree::Order
          compute_order(computable)
        when Spree::LineItem
          compute_line_item(computable)
      end
    end


    private

      def rate
        rate = self.calculable
      end

      def compute_order(order)
        matched_line_items = order.line_items.select do |line_item|
          line_item.product.tax_category == rate.tax_category
        end

        line_items_total = matched_line_items.sum(&:price)
        line_items_total * rate.amount
      end

      def compute_line_item(line_item)
        if line_item.product.tax_category == rate.tax_category
          line_item.price * rate.amount
        else
          0
        end
      end

  end
end
