default_store = Spree::Store.default
default_store.checkout_zone = Spree::Zone.find_by(name: 'North America')
default_store.default_country = Spree::Country.default
default_store.url = Rails.env.development? ? 'localhost:3000' : 'demo.spreecommerce.org'
default_store.save!

eu_store = Spree::Store.find_or_initialize_by(code: 'eustore')
eu_store.name = 'EU Store'
eu_store.url = Rails.env.development? ? 'eu.lvh.me:3000' : 'demo-eu.spreecommerce.org'
eu_store.mail_from_address = 'eustore@example.com'
eu_store.default_currency = 'EUR'
eu_store.default_locale = 'de'
eu_store.checkout_zone = Spree::Zone.find_by(name: 'EU_VAT')
eu_store.default_country = Spree::Country.find_by(iso: 'DE')
eu_store.save!

uk_store = Spree::Store.find_or_initialize_by(code: 'ukstore')
uk_store.name = 'UK Store'
uk_store.url = Rails.env.development? ? 'uk.lvh.me:3000' : 'demo-uk.spreecommerce.org'
uk_store.mail_from_address = 'ukstore@example.com'
uk_store.default_currency = 'GBP'
uk_store.default_locale = 'en'
uk_store.checkout_zone = Spree::Zone.find_by(name: 'UK_VAT')
uk_store.default_country = Spree::Country.find_by(iso: 'GB')
uk_store.save!

currencies = %w[EUR GBP]
Spree::Price.where(currency: 'USD').each do |price|
  currencies.each do |currency|
    new_price = Spree::Price.find_or_initialize_by(currency: currency, variant: price.variant)
    new_price.amount = price.amount
    new_price.save
  end
end

Spree::PaymentMethod.all.each do |payment_method|
  payment_method.stores = Spree::Store.all
end
