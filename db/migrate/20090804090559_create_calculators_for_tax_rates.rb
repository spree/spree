class CreateCalculatorsForTaxRates < ActiveRecord::Migration
  def self.up
    TaxRate.find(:all).each do |tax_rate|
      case tax_rate.tax_type
      when 'SalesTax' 
        tax_rate.calculator = Calculator::SalesTax.new
      when 'Vat'
        tax_rate.calculator = Calculator::Vat.new
      end
      tax_rate.save!
    end
  end

  def self.down
  end
end
