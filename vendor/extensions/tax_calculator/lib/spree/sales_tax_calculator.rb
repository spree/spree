module Spree #:nodoc:
  class SalesTaxCalculator

    def self.calculate_tax(order, rates) 
      return 0 if rates.empty?
      taxable_totals = {}
      order.line_items.each do |line_item|
        next unless tax_category = line_item.variant.product.tax_category
        next unless rate = rates[tax_category]
        taxable_totals[tax_category] ||= 0
        taxable_totals[tax_category] += line_item.total
      end

      return 0 if taxable_totals.empty?
      tax = 0
      rates.each do |category, rate|
        return unless taxable_total = taxable_totals[category]   
        tax += taxable_total * rate.amount
      end
      tax
    end
  end
end