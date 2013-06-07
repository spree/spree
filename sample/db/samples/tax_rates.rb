north_america = Spree::Zone.find_by_name!("North America")
clothing = Spree::TaxCategory.find_by_name!("Clothing")
tax_rate = Spree::TaxRate.create(
  :name => "North America",
  :zone => north_america, 
  :amount => 0.05,
  :tax_category => clothing)
tax_rate.calculator = Spree::Calculator::DefaultTax.create!
tax_rate.save!
