module Spree #:nodoc:
  class VatCalculator
    def self.calculate_tax(order, rates)      
      return 0 if rates.empty?
      taxable_totals = {}
      order.line_items.each do |line_item|
        next unless tax_category = line_item.variant.product.tax_category
        next unless rate = rates[tax_category]
        taxable_totals[tax_category] ||= 0
        taxable_totals[tax_category] += line_item.price * rate.amount * line_item.quantity
      end

      return 0 if taxable_totals.empty?
      tax = 0
      taxable_totals.values.each do |total|
        tax += total
      end
      tax
    end
  end
end