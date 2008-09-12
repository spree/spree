module Spree #:nodoc:
  class VatCalculator
    def self.calculate_tax(order, rates)      
      return 0 if rates.empty?
      taxable_totals = {}
      order.line_items.each do |line_item|
        next unless tax_category = line_item.variant.product.tax_category
        next unless rate = rates.find { | vat_rate | vat_rate.tax_category_id = tax_category.id }
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
    
    def self.calculate_tax_on(product_or_variant)
      # get default zone using default_country_id value
      vat_rates = Rails.cache.fetch('vat_rates') do
        default_country = Country.find(Spree::Config[:default_country_id], :include => {:zone_members => :parent}) 
        default_zone = default_country.zone_members[0].parent unless default_country.zone_members.empty?
        
        default_zone.nil? ? nil : TaxRate.find_all_by_zone_id_and_tax_type(default_zone, TaxRate::TaxType::VAT)  
      end
     
      return 0 if vat_rates.nil?

      return 0 unless tax_category = product_or_variant.is_a?(Product) ? product_or_variant.tax_category : product_or_variant.product.tax_category
      return 0 unless rate = vat_rates.find { | vat_rate | vat_rate.tax_category_id = tax_category.id }

      (product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price) * rate.amount
    end
    
    
  end
end