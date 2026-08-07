FactoryBot.define do
  # Countries are reference data: a record only makes sense if its ISO code is
  # one the countries gem knows, since that is what resolves subdivisions and
  # names. The sequence walks a pool of real codes so specs that just want
  # "some other country" keep working, and reuses an existing row rather than
  # colliding with the unique index on iso.
  factory :country, class: Spree::Country do
    transient do
      # Deliberately not US — specs that want the default store's country ask
      # for :country_us. These are countries with subdivisions the gem knows.
      sequence(:iso_pool_index) { |n| n }
    end

    # A spec naming a country ("France") gets that country, rather than the
    # name being pinned onto whichever code the pool handed out — which would
    # collide on the unique name index. Reads the override without declaring
    # `name` itself, so an unnamed country still takes its name from the gem.
    iso do
      requested_name = @overrides && (@overrides[:name] || @overrides['name'])
      named = requested_name.present? ? ISO3166::Country.find_country_by_any_name(requested_name) : nil
      named&.alpha2 || Spree::TestingSupport::CountryPool.iso_for(iso_pool_index)
    end

    initialize_with do
      iso_code = iso.to_s.upcase
      data = ISO3166::Country[iso_code]

      Spree::Country.find_or_initialize_by(iso: iso_code).tap do |country|
        country.iso3 ||= data&.alpha3 || iso_code
        country.name ||= data&.iso_short_name || iso_code
        country.iso_name ||= (data&.iso_short_name || iso_code).upcase
        country.numcode ||= data&.number
        country.states_required = Spree::Address::STATES_REQUIRED.include?(iso_code)
        country.zipcode_required = !Spree::Address::NO_ZIPCODE_ISO_CODES.include?(iso_code)
      end
    end

    factory :country_us, class: Spree::Country, parent: :country do
      iso { 'US' }
    end
  end
end
