Spree::Sample.load_sample("orders")

first_order = Spree::Order.find_by_number!("R123456789")
last_order = Spree::Order.find_by_number!("R987654321")

first_order.adjustments.create!({
  :amount => 0,
  :source => first_order,
  :originator => Spree::TaxRate.find_by_name!("North America"),
  :label => "Tax",
  :locked => false,
  :mandatory => true
}, :without_protection => true)

last_order.adjustments.create!({
  :amount => 0,
  :source => last_order,
  :originator => Spree::TaxRate.find_by_name!("North America"),
  :label => "Tax",
  :locked => false,
  :mandatory => true
}, :without_protection => true)

first_order.adjustments.create!({
  :amount => 0,
  :source => first_order,
  :originator => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :label => "Shipping",
  :locked => true,
  :mandatory => true
}, :without_protection => true)

last_order.adjustments.create!({
  :amount => 0,
  :source => last_order,
  :originator => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :label => "Shipping",
  :locked => true,
  :mandatory => true
}, :without_protection => true)
