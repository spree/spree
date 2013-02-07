first_order = Spree::Order.find_by_number!("R123456789")
last_order = Spree::Order.find_by_number!("R987654321")

Spree::Shipment.create!(
  :order => first_order,
  :number => Array.new(11){rand(11)}.join,
  :shipping_method => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :address => Spree::Address.first,
  :state => "pending")

Spree::Shipment.create!(
  :order => last_order,
  :number => Array.new(11){rand(11)}.join,
  :shipping_method => Spree::ShippingMethod.find_by_name!("UPS Ground (USD)"),
  :address => Spree::Address.first,
  :state => "pending")
