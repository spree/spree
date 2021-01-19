default_store = Spree::Store.default
default_store.checkout_zone = Spree::Zone.find_by(name: 'North America')
default_store.default_country = Spree::Country.default
default_store.save!

eu_store = Spree::Store.find_or_initialize_by(code: 'eustore')
eu_store.name = 'EU Store'
eu_store.url = 'eu.spreecommerce.org'
eu_store.mail_from_address = 'eustore@example.com'
eu_store.default_currency = 'EUR'
eu_store.default_locale = 'de'
eu_store.checkout_zone = Spree::Zone.find_by(name: 'EU_VAT')
eu_store.default_country = Spree::Country.find_by(iso: 'DE')
eu_store.save!

uk_store = Spree::Store.find_or_initialize_by(code: 'ukstore')
uk_store.name = 'UK Store'
uk_store.url = 'uk.spreecommerce.org'
uk_store.mail_from_address = 'ukstore@example.com'
uk_store.default_currency = 'GBP'
uk_store.default_locale = 'en'
uk_store.checkout_zone = Spree::Zone.find_by(name: 'UK_VAT')
uk_store.default_country = Spree::Country.find_by(iso: 'GB')
uk_store.save!

Spree::Config[:show_store_selector] = true
