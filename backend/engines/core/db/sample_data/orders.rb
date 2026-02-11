store = Spree::Store.default

# Find products created by the product import
product_1 = Spree::Product.find_by(name: 'Denim Shirt')
product_2 = Spree::Product.find_by(name: 'Checked Shirt')

unless product_1 && product_2
  puts '  Skipping orders: required products not found'
  return
end

# Build addresses for orders
us = Spree::Country.find_by!(iso: 'US')
ny = us.states.find_by(abbr: 'NY')

billing_address = Spree::Address.find_or_create_by!(
  firstname: 'John',
  lastname: 'Doe',
  address1: '7735 Old Georgetown Rd',
  city: 'Bethesda',
  state: ny,
  zipcode: '20814',
  country: us,
  phone: '555-0199'
)

shipping_address = Spree::Address.find_or_create_by!(
  firstname: 'John',
  lastname: 'Doe',
  address1: '1600 Pennsylvania Ave NW',
  city: 'Washington',
  state: ny,
  zipcode: '20500',
  country: us,
  phone: '555-0199'
)

# Create orders
orders = []

orders << store.orders.where(
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

orders.each(&:create_proposed_shipments)

Spree::Order.where(id: orders.map(&:id)).update_all(state: :complete, completed_at: Time.current - 1.day)

# Adjustments (tax)
tax_rate = Spree::TaxRate.find_by(name: 'California')

if tax_rate
  orders.each do |order|
    order.all_adjustments.where(
      adjustable: order,
      source: tax_rate,
      label: 'Tax',
      state: 'open',
      mandatory: true
    ).first_or_create! do |adj|
      adj.amount = 0
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
    order.update_with_updater!
    payment = order.payments.where(
      amount: BigDecimal(order.total, 4),
      source: credit_card.clone,
      payment_method: method
    ).first_or_create!
    payment.update_columns(state: 'pending', response_code: '12345')
  end
end

# Reimbursement
first_complete_order = Spree::Order.complete.first
Spree::Reimbursement.create(order: first_complete_order) if first_complete_order
