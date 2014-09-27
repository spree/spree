Spree::Sample.load_sample("orders")

first_order = Spree::Order.find_by_number!("R123456789")
last_order = Spree::Order.find_by_number!("R987654321")

first_order.create_adjustment!(
  adjustable: first_order,
  amount:     0,
  source:     Spree::TaxRate.find_by_name!('North America'),
  label:      'Tax',
  state:      'open',
  mandatory:  true
)

last_order.create_adjustment!(
  adjustable: last_order,
  amount:     0,
  source:     Spree::TaxRate.find_by_name!('North America'),
  label:      'Tax',
  state:      'open',
  mandatory:  true
)
