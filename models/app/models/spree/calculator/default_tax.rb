require_dependency 'spree/calculator'

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
        self.calculable
      end

      def compute_order(order)
        matched_line_items = order.line_items.select do |line_item|
          line_item.product.tax_category == rate.tax_category
        end

        line_items_total = matched_line_items.sum(&:total)
        round_to_two_places(line_items_total * rate.amount)
      end

      def compute_line_item(line_item)
        if line_item.product.tax_category == rate.tax_category
          deduced_total_by_rate(line_item.total, rate)
        else
          0
        end
      end

      def round_to_two_places(amount)
        BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      end

      def deduced_total_by_rate(total, rate)
        round_to_two_places(total - ( total / (1 + rate.amount) ) )
      end

  end
end
