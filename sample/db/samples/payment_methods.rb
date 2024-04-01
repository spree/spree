Spree::Sample.load_sample('stores')

check_paymemt_method = Spree::PaymentMethod::Check.where(
  name: 'Чек',
  description: 'Оплата чеком.',
  active: true
).first_or_initialize

check_paymemt_method.stores = Spree::Store.all
check_paymemt_method.save!
