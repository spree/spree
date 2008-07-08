module Spree #:nodoc:
  module TaxCalculator
    def calculate_tax(order)
      # tax is zero if ship address does not match any existing zone
      return 0 unless zone = Zone.match(order.ship_address).first
      # find any tax rates that match this zone
      tax_rates = TaxRate.by_zone(zone)
      # tax is also zero if none of the zones is associated with a tax rate
      return 0 if tax_rates.empty?
      
      sales_tax_rates = {}
      tax_rates.each {|rate| sales_tax_rates[rate.tax_category] = rate if rate.tax_type == TaxRate::TaxType::SALES_TAX}

      vat_rates = {}
      tax_rates.each {|rate| vat_rates[rate.tax_category] = rate if rate.tax_type == TaxRate::TaxType::VAT}
      
      sales_tax = Spree::SalesTaxCalculator.calculate_tax(order, sales_tax_rates)
      vat_tax = Spree::VatCalculator.calculate_tax(order, vat_rates)
      # note we expect only one of these tax calculations to have a value but its technically possible to model
      # both a sales tax and vat if you wanted to do that for some reason
      sales_tax + vat_tax
    end
  end
end