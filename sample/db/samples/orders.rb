Spree::Sample.load_sample('addresses')
Spree::Sample.load_sample('products')

store = Spree::Store.default
product_1 = Spree::Product.find_by!(name: 'Denim Shirt')
product_2 = Spree::Product.find_by!(name: 'Checked Shirt')

orders = []
orders << store.orders.where(
  store: store,
  number: 'R123456789',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_1.default_variant.amount_in(order.currency)
  order.adjustment_total = product_1.default_variant.amount_in(order.currency)
  order.total = product_1.default_variant.amount_in(order.currency) * 2
end

orders << store.orders.where(
  number: 'R987654321',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_2.default_variant.amount_in(order.currency)
  order.adjustment_total = product_2.default_variant.amount_in(order.currency)
  order.total = product_2.default_variant.amount_in(order.currency) * 2
  order.shipping_address = Spree::Address.first
  order.billing_address = Spree::Address.last
end

unless orders[0].line_items.any?
  orders[0].line_items.new(
    variant: product_1.default_variant,
    quantity: 1,
    price: product_1.default_variant.amount_in(orders[0].currency)
  ).save!
end

unless orders[1].line_items.any?
  orders[1].line_items.new(
    variant: product_2.default_variant,
    quantity: 1,
    price: product_1.default_variant.amount_in(orders[1].currency)
  ).save!
end

orders.each(&:create_proposed_shipments)

Spree::Order.where(id: orders.map(&:id)).update_all(state: :complete, completed_at: Time.current - 1.day)
