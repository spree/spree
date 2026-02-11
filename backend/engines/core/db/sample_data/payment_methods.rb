cc_payment_method = Spree::Gateway::Bogus.where(
  name: 'Credit Card',
  description: 'Bogus payment gateway.',
  active: true
).first_or_initialize

cc_payment_method.stores = Spree::Store.all
cc_payment_method.save!

check_payment_method = Spree::PaymentMethod::Check.where(
  name: 'Check',
  description: 'Pay by check.',
  active: true
).first_or_initialize

check_payment_method.stores = Spree::Store.all
check_payment_method.save!
