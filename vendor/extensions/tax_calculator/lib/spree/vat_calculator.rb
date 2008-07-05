module Spree #:nodoc:
  class VatCalculator
    def self.calculate_tax(order, rates)
      # TODO - skip if vat does not apply
      
=begin
      # Check for taxable items
      tax = 0
      order.line_items.each do |line_item|
        product = line_item.variant.product
        next unless tax_category = product.property_values.tax_category.first
        next unless tax_rate = VatTaxRate.category(tax_category).first      
        tax += (line_item.quantity * line_item.price * tax_rate.rate)
      end
      order.tax_amount = tax
=end
      0
    end
  end
end