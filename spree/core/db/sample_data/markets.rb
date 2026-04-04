store = Spree::Store.default

us = Spree::Country.find_by(iso: 'US')
ca = Spree::Country.find_by(iso: 'CA')

if us
  # Store auto-creates a default market on creation — update it rather than creating a new one
  us_market = store.markets.default.first || store.markets.order(:position).first || store.markets.new
  us_market.name = 'US'
  us_market.currency = 'USD'
  us_market.default_locale = 'en'
  us_market.default = true
  us_market.countries = [us, ca].compact
  us_market.save!
end

eu_zone = Spree::Zone.find_by(name: 'EU_VAT')

if eu_zone
  eu_countries = eu_zone.zone_members.where(zoneable_type: 'Spree::Country').map(&:zoneable)

  if eu_countries.any?
    eu_market = store.markets.find_or_initialize_by(name: 'Europe')
    eu_market.currency = 'EUR'
    eu_market.default_locale = 'de'
    eu_market.supported_locales = 'de,fr,es,it'
    eu_market.countries = eu_countries
    eu_market.save!
  end
end
