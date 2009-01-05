module Spree #:nodoc:
  module TaxCalculator
    def calculate_tax      
      # tax is zero if ship address does not match any existing tax zone
      tax_rates = TaxRate.all.find_all { |rate| rate.zone.include?(ship_address) }
      return 0 if tax_rates.empty?  
      sales_tax_rates = tax_rates.find_all { |rate| rate.tax_type == TaxRate::TaxType::SALES_TAX }
      vat_rates = tax_rates.find_all { |rate| rate.tax_type == TaxRate::TaxType::VAT }

      # note we expect only one of these tax calculations to have a value but its technically possible to model
      # both a sales tax and vat if you wanted to do that for some reason
      sales_tax = Spree::SalesTaxCalculator.calculate_tax(self, sales_tax_rates)
      vat_tax = Spree::VatCalculator.calculate_tax(self, vat_rates)
      
      sales_tax + vat_tax
    end
  end
end