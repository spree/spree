Spree::Sample.load_sample("orders")

first_order = Spree::Order.find_by_number!("R123456789")
last_order = Spree::Order.find_by_number!("R987654321")

first_order.line_items.create!(
  :variant => Spree::Product.find_by_name!("Ruby on Rails Tote").master,
  :quantity => 1,
  :price => 15.99)

last_order.line_items.create!(
  :variant => Spree::Product.find_by_name!("Ruby on Rails Bag").master,
  :quantity => 1,
  :price => 22.99)
