Spree::Store.all.find_each do |store|
  cc_payment_method = store.payment_methods.find_or_initialize_by(
    type: 'Spree::Gateway::Bogus',
    name: 'Credit Card',
    description: 'Bogus payment gateway.',
    active: true
  )
  cc_payment_method.display_on = 'back_end'
  cc_payment_method.save!

  check_payment_method = store.payment_methods.find_or_initialize_by(
    type: 'Spree::PaymentMethod::Check',
    name: 'Check',
    description: 'Pay by check.',
    active: true
  )
  check_payment_method.display_on = 'back_end'
  check_payment_method.save!
end
