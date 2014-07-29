north_zone = Spree::Zone.find_by_name("צפון")
default = Spree::TaxCategory.find_by_name!("ברירת מחדל")
tax_rate = Spree::TaxRate.create(
  :name => "מס הכנסה",
  :zone => north_zone, 
  :amount => 0.18,
  :tax_category => default)
tax_rate.calculator = Spree::Calculator::DefaultTax.create!
tax_rate.save!
