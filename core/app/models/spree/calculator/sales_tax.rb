module Spree
  class Calculator::SalesTax < Calculator
    def self.description
      I18n.t(:sales_tax)
    end

    def compute(order)
      rate = self.calculable
      line_items = order.line_items.select { |i| i.product.tax_category == rate.tax_category }
      line_items.inject(0) { |sum, line_item| sum += line_item.total * rate.amount }
    end
  end
end
