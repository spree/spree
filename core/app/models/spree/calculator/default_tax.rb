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
        unless order.adjustments.promotion.blank? 
          adjusted_total = line_items_total + order.adjustments.eligible.sum(:amount) 
          unless adjusted_total.nil?  
            round_to_two_places( adjusted_total * rate.amount ) 
          else
            0
          end
        else
          round_to_two_places(line_items_total * rate.amount) 
        end 
      end

      def compute_line_item(line_item)
        if line_item.product.tax_category == rate.tax_category
          if rate.included_in_price
            deduced_total_by_rate(line_item.total, rate)
          else
            round_to_two_places(line_item.total * rate.amount)
          end
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
