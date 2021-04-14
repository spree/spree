Spree::Sample.load_sample('addresses')
Spree::Sample.load_sample('products')

product_1 = Spree::Product.find_by!(name: 'Denim Shirt')
product_2 = Spree::Product.find_by!(name: 'Checked Shirt')

orders = []
orders << Spree::Order.where(
  number: 'R123456789',
  email: 'spree@example.com'
).first_or_create! do |order|
  order.item_total = product_1.master.price
  order.adjustment_total = product_1.master.price
  order.total = product_1.master.price * 2
end

orders << Spree::Order.where(
  number: 'R987654321',
  email: 'spree@example.com'
).first_or_create! do |order|
  order.item_total = product_2.master.price
  order.adjustment_total = product_2.master.price
  order.total = product_2.master.price * 2
  order.shipping_address = Spree::Address.first
  order.billing_address = Spree::Address.last
end

unless orders[0].line_items.any?
  orders[0].line_items.new(
    variant: product_1.master,
    quantity: 1,
    price: product_1.master.price
  ).save!
end

unless orders[1].line_items.any?
  orders[1].line_items.new(
    variant: product_2.master,
    quantity: 1,
    price: product_1.master.price
  ).save!
end

orders.each(&:create_proposed_shipments)

store = Spree::Store.default

orders.each do |order|
  order.state = 'complete'
  order.store = store
  order.completed_at = Time.current - 1.day
  order.save!
end
