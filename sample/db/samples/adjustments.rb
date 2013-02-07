Spree::Sample.load_sample("orders")

first_order = Spree::Order.find_by_number!("R123456789")
last_order = Spree::Order.find_by_number!("R987654321")

first_order.adjustments.create!(
  :amount => 0,
  :source => first_order,
  :originator => Spree::TaxRate.find_by_name!("North America"),
  :label => "Tax",
  :state => "open",
  :mandatory => true)

last_order.adjustments.create!(
  :amount => 0,
  :source => last_order,
  :originator => Spree::TaxRate.find_by_name!("North America"),
  :label => "Tax",
  :state => "open",
  :mandatory => true)

first_order.adjustments.create!(
  :amount => 0,
  :source => first_order,
  :originator => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :label => "Shipping",
  :state => "finalized",
  :mandatory => true)

last_order.adjustments.create!(
  :amount => 0,
  :source => last_order,
  :originator => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :label => "Shipping",
  :state => "finalized",
  :mandatory => true)
