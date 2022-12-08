Spree::Sample.load_sample('addresses')
Spree::Sample.load_sample('products')

product_1 = Spree::Product.find_by!(name: 'Denim Shirt')
product_2 = Spree::Product.find_by!(name: 'Checked Shirt')

orders = []
orders << Spree::Order.where(
  number: 'R123456789',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_1.master.amount_in(order.currency)
  order.adjustment_total = product_1.master.amount_in(order.currency)
  order.total = product_1.master.amount_in(order.currency) * 2
end

orders << Spree::Order.where(
  number: 'R987654321',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_2.master.amount_in(order.currency)
  order.adjustment_total = product_2.master.amount_in(order.currency)
  order.total = product_2.master.amount_in(order.currency) * 2
  order.shipping_address = Spree::Address.first
  order.billing_address = Spree::Address.last
end

unless orders[0].line_items.any?
  orders[0].line_items.new(
    variant: product_1.master,
    quantity: 1,
    price: product_1.master.amount_in(orders[0].currency)
  ).save!
end

unless orders[1].line_items.any?
  orders[1].line_items.new(
    variant: product_2.master,
    quantity: 1,
    price: product_1.master.amount_in(orders[1].currency)
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
