default_store = Spree::Store.default
default_store.name_en = "Spree Demo Site"
default_store.name_uk = "Spree Демо Сайт"
default_store.checkout_zone = Spree::Zone.find_by(name: 'Україна')
default_store.default_country = Spree::Country.find_by(iso: 'UA')
default_store.default_currency = 'UAH'
default_store.supported_currencies = 'UAH'
default_store.supported_locales = 'en,uk'
default_store.default_locale = 'uk'
default_store.mail_from_address = 'no-reply@example.com'
default_store.url = Rails.env.development? ? 'localhost:4000' : ENV["HOST"]
default_store.save!

currencies = %w[UAH]
Spree::Price.where(currency: 'USD').each do |price|
  currencies.each do |currency|
    new_price = Spree::Price.find_or_initialize_by(currency: currency, variant: price.variant)
    new_price.amount = price.amount * 40 # USD in UAH
    new_price.save
  end
end

Spree::PaymentMethod.all.each do |payment_method|
  payment_method.stores = Spree::Store.all
end

if defined?(Spree::StoreProduct) && Spree::Product.method_defined?(:stores)
  Spree::Product.all.each do |product|
    product.store_ids = Spree::Store.ids
    product.save
  end
end
