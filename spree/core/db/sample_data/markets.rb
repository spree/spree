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
  eu_countries = eu_zone.zone_members.where(zoneable_type: 'Spree::Country').map(&:zoneable).uniq.compact

  if eu_countries.any?
    eu_market = store.markets.find_or_initialize_by(name: 'Europe')
    eu_market.currency = 'EUR'
    eu_market.default_locale = 'de'
    eu_market.supported_locales = 'de,fr,es,it'
    eu_market.countries = eu_countries
    eu_market.save!
  end
end

# Additional sample markets for the remaining continents. Each market pulls
# its countries from the matching shipping zone so it only includes countries
# with shipping coverage (and therefore valid market countries). Countries
# already assigned to another market in the store are skipped, because
# Spree::MarketCountry requires each country to belong to at most one market
# per store.
[
  { name: 'South America', zone: 'South America', currency: 'USD', default_locale: 'es', supported_locales: 'es,pt' },
  { name: 'Middle East', zone: 'Middle East', currency: 'USD', default_locale: 'en', supported_locales: 'en,ar' },
  { name: 'Africa', zone: 'Africa', currency: 'USD', default_locale: 'en', supported_locales: 'en,fr,ar' },
  { name: 'Asia', zone: 'Asia', currency: 'USD', default_locale: 'en', supported_locales: 'en' },
  { name: 'Oceania', zone: 'Australia and Oceania', currency: 'AUD', default_locale: 'en', supported_locales: 'en' }
].each do |attrs|
  zone = Spree::Zone.find_by(name: attrs[:zone])
  next unless zone

  market = store.markets.find_or_initialize_by(name: attrs[:name])

  assigned_scope = Spree::MarketCountry.joins(:market).
    where(spree_markets: { store_id: store.id, deleted_at: nil })
  assigned_scope = assigned_scope.where.not(market_id: market.id) if market.persisted?
  assigned_country_ids = assigned_scope.pluck(:country_id).to_set

  countries = zone.zone_members.where(zoneable_type: 'Spree::Country').map(&:zoneable).uniq.compact
  countries = countries.reject { |c| assigned_country_ids.include?(c.id) }
  next if countries.empty?

  market.currency = attrs[:currency]
  market.default_locale = attrs[:default_locale]
  market.supported_locales = attrs[:supported_locales]
  market.countries = countries
  market.save!
end
