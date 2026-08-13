store = Spree::Store.default

# Find products created by the product import
product_1 = Spree::Product.find_by(name: 'Automatic Espresso Machine')
product_2 = Spree::Product.find_by(name: 'Drip Coffee Maker 1.5L')

unless product_1 && product_2
  puts '  Skipping orders: required products not found'
  return
end

# Build addresses for orders
us_iso = 'US'
ny_abbr = 'NY'

billing_address = Spree::Address.find_or_create_by!(
  firstname: 'John',
  lastname: 'Doe',
  address1: '7735 Old Georgetown Rd',
  city: 'Bethesda',
  state_abbr: ny_abbr,
  zipcode: '20814',
  country_iso: us_iso,
  phone: '555-0199'
)

shipping_address = Spree::Address.find_or_create_by!(
  firstname: 'John',
  lastname: 'Doe',
  address1: '1600 Pennsylvania Ave NW',
  city: 'Washington',
  state_abbr: ny_abbr,
  zipcode: '20500',
  country_iso: us_iso,
  phone: '555-0199'
)

# Create orders. Numbers are fixed rather than generated — the number is the
# `first_or_create!` key that makes a re-run idempotent — and match the 6.0
# sequential default so a sample store looks like a real one. Real orders
# created afterwards skip past taken values on their own.
orders = []

orders << store.orders.where(
  number: 'R1001',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_1.default_variant.amount_in(order.currency)
  order.adjustment_total = product_1.default_variant.amount_in(order.currency)
  order.total = product_1.default_variant.amount_in(order.currency) * 2
end

orders << store.orders.where(
  number: 'R1002',
  email: 'spree@example.com',
  currency: 'USD'
).first_or_create! do |order|
  order.item_total = product_2.default_variant.amount_in(order.currency)
  order.adjustment_total = product_2.default_variant.amount_in(order.currency)
  order.total = product_2.default_variant.amount_in(order.currency) * 2
  order.shipping_address = shipping_address
  order.billing_address = billing_address
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
    price: product_2.default_variant.amount_in(orders[1].currency)
  ).save!
end

orders.each(&:rebuild_fulfillments!)

Spree::Order.where(id: orders.map(&:id)).update_all(status: 'placed', completed_at: Time.current - 1.day)

# Tax lines (zero-amount sample rows against the California rate)
tax_rate = Spree::TaxRate.find_by(name: 'California')

if tax_rate
  orders.each do |order|
    line_item = order.line_items.first
    next if line_item.nil?

    order.tax_lines.where(
      line_item: line_item,
      tax_rate: tax_rate,
      label: 'Tax'
    ).first_or_create! do |tax_line|
      tax_line.amount = 0
      tax_line.rate = tax_rate.amount
      tax_line.included = tax_rate.included_in_price
      tax_line.provider_id = 'internal'
    end
  end
end

# Payments
method = Spree::PaymentMethod.where(name: 'Credit Card', active: true).first

if method
  Spree::Gateway.class_eval do
    def self.current
      Spree::Gateway::Bogus.new
    end
  end

  credit_card = Spree::CreditCard.find_or_initialize_by(gateway_customer_profile_id: 'BGS-1234')
  credit_card.cc_type = 'visa'
  credit_card.month = 12
  credit_card.year = 2.years.from_now.year
  credit_card.last_digits = '1111'
  credit_card.name = 'Sean Schofield'
  credit_card.save!

  orders.each do |order|
    order.recalculate_totals!
    payment = order.payments.where(
      amount: BigDecimal(order.total, 4),
      source: credit_card.clone,
      payment_method: method
    ).first_or_create!
    payment.update_columns(state: 'pending', response_code: "BGS-#{SecureRandom.hex(6)}")
  end
end

# Statuses are derive-then-persist; the direct writes above bypass the
# event subscribers, so recompute explicitly.
orders.each { |order| order.reload.update_statuses! }

# A return in progress, so the admin has something to look at. Built through
# the workflows rather than by direct writes — they own every transition.
first_complete_order = Spree::Order.complete.first
if first_complete_order && first_complete_order.fulfillment_items.any?
  fulfillment_item = first_complete_order.fulfillment_items.first

  Spree::Returns::Create.call(
    order: first_complete_order,
    items: [{ fulfillment_item: fulfillment_item, quantity: 1 }],
    stock_location: fulfillment_item.fulfillment&.stock_location || Spree::StockLocation.first,
    reason: Spree::ReturnReason.first,
    memo: 'Sample return'
  )
end
