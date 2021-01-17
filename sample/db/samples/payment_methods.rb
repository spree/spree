Spree::Gateway::Bogus.where(
  name: 'Credit Card',
  description: 'Bogus payment gateway.',
  active: true
).first_or_create! do |payment_method|
  payment_method.store_ids = Spree::Store.ids
end

Spree::PaymentMethod::Check.where(
  name: 'Check',
  description: 'Pay by check.',
  active: true
).first_or_create! do |payment_method|
  payment_method.store_ids = Spree::Store.ids
end
