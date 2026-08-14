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

# Each market names its countries as ISO codes directly — the zone seeds these
# groupings used to come from are gone. Countries already assigned to another
# market in the store are skipped, because Spree::MarketCountry requires each
# country to belong to at most one market per store.
EU_ISOS = %w[PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG LT CY LU MT DK NL EE HR CZ GR].freeze

eu_countries = Spree::Country.where(iso: EU_ISOS).to_a
if eu_countries.any?
  eu_market = store.markets.find_or_initialize_by(name: 'Europe')
  eu_market.currency = 'EUR'
  eu_market.default_locale = 'de'
  eu_market.supported_locales = 'de,fr,es,it'
  eu_market.countries = eu_countries
  eu_market.save!
end

[
  { name: 'South America', isos: %w[AR BO BR CL CO EC FK GF GY PY PE SR UY VE],
    currency: 'USD', default_locale: 'es', supported_locales: 'es,pt' },
  { name: 'Middle East', isos: %w[BH EG IR IQ IL JO KW LB OM QA SA SY TR AE YE],
    currency: 'USD', default_locale: 'en', supported_locales: 'en,ar' },
  { name: 'Africa', isos: %w[DZ AO BJ BW BF BI CV CM CF TD KM CG CD CI DJ GQ ER SZ ET GA GM GH GN GW KE LS LR LY
                             MG MW ML MR MU YT MA MZ NA NE NG RE RW SH ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW],
    currency: 'USD', default_locale: 'en', supported_locales: 'en,fr,ar' },
  { name: 'Asia', isos: %w[AF AM AZ BD BT BN KH CN CX CC GE HK IN ID JP KZ KG LA MO MY MV MN MM NP
                           KP PK PS PH SG KR LK TW TJ TH TM UZ VN],
    currency: 'USD', default_locale: 'en', supported_locales: 'en' },
  { name: 'Oceania', isos: %w[AU NZ PG FJ SB VU NC PF WS AS GU KI MH FM NR NU NF MP PW PN TK TO TV WF CK],
    currency: 'AUD', default_locale: 'en', supported_locales: 'en' }
].each do |attrs|
  market = store.markets.find_or_initialize_by(name: attrs[:name])

  assigned_scope = Spree::MarketCountry.joins(:market).
    where(spree_markets: { store_id: store.id, deleted_at: nil })
  assigned_scope = assigned_scope.where.not(market_id: market.id) if market.persisted?
  assigned_country_ids = assigned_scope.pluck(:country_id).to_set

  countries = Spree::Country.where(iso: attrs[:isos]).reject { |c| assigned_country_ids.include?(c.id) }
  next if countries.empty?

  market.currency = attrs[:currency]
  market.default_locale = attrs[:default_locale]
  market.supported_locales = attrs[:supported_locales]
  market.countries = countries
  market.save!
end
