eu_store = Spree::Store.find_or_initialize_by(code: 'eustore')
eu_store.name = 'EU Store'
eu_store.url = 'eu.spreecommerce.org'
eu_store.mail_from_address = 'eustore@example.com'
eu_store.default_currency = 'EUR'
eu_store.default_locale = 'de'
eu_store.save!

uk_store = Spree::Store.find_or_initialize_by(code: 'ukstore')
uk_store.name = 'UK Store'
uk_store.url = 'uk.spreecommerce.org'
uk_store.mail_from_address = 'ukstore@example.com'
uk_store.default_currency = 'GBP'
uk_store.default_locale = 'en'
uk_store.save!
