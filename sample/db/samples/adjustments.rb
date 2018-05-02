Spree::Sample.load_sample('orders')

first_order = Spree::Order.find_by!(number: 'R123456789')
last_order = Spree::Order.find_by!(number: 'R987654321')

first_order.adjustments.where(
  source: Spree::TaxRate.find_by!(name: 'North America'),
  order: first_order,
  label: 'Tax',
  state: 'open',
  mandatory: true
).first_or_create! do |adj|
  adj.amount = 0
end

last_order.adjustments.where(
  source: Spree::TaxRate.find_by!(name: 'North America'),
  order: last_order,
  label: 'Tax',
  state: 'open',
  mandatory: true
).first_or_create! do |adj|
  adj.amount = 0
end
