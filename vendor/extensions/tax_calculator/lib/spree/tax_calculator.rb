module Spree #:nodoc:
  module TaxCalculator
        
    def calculate_tax
      # tax is zero if ship address does not match any existing zone
      return 0 unless zone = Zone.match(address).first
      # find any tax rates that match this zone
      tax_rates = TaxRate.by_zone(zone)
      # tax is also zero if none of the zones is associated with a tax rate
      return 0 if tax_rates.empty?
      
      sales_tax_rates = {}
      tax_rates.each {|rate| sales_tax_rates[rate.tax_category] = rate if rate.tax_type == TaxRate::TaxType::SALES_TAX}

      vat_rates = {}
      tax_rates.each {|rate| vat_rates[rate.tax_category] = rate if rate.tax_type == TaxRate::TaxType::VAT}

      # note we expect only one of these tax calculations to have a value but its technically possible to model
      # both a sales tax and vat if you wanted to do that for some reason
      sales_tax = Spree::SalesTaxCalculator.calculate_tax(self, sales_tax_rates)
      vat_tax = Spree::VatCalculator.calculate_tax(self, vat_rates)
      
      sales_tax + vat_tax
      #self.update_attribute(:tax_amount, sales_tax + vat_tax)
    end
  end
end