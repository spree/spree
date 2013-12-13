Spree::Sample.load_sample("addresses")

order = Spree::Order.create!({
  :number => "R123456789",
  :email => "spree@example.com",
  :item_total => 150.95,
  :adjustment_total => 150.95,
  :shipping_method => Spree::ShippingMethod.first,
  :total => 301.90,
  :shipping_address => Spree::Address.first,
  :billing_address => Spree::Address.last
}, :without_protection => true)

order.create_shipment!
order.state = "complete"
order.completed_at = Time.now - 1.day
order.save!

order = Spree::Order.create!({
  :number => "R987654321",
  :email => "spree@example.com",
  :item_total => 15.95,
  :adjustment_total => 15.95,
  :total => 31.90,
  :shipping_method => Spree::ShippingMethod.first,
  :shipping_address => Spree::Address.first,
  :billing_address => Spree::Address.last
}, :without_protection => true)

order.create_shipment!
order.state = "complete"
order.completed_at = Time.now - 1.day
order.save!
