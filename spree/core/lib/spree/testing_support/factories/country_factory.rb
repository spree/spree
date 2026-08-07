FactoryBot.define do
  # Countries are reference data supplied by the countries gem, not records —
  # there is nothing to persist, so this hands back the registry's value
  # object. `create(:country)` and `build(:country)` are equivalent.
  factory :country, class: Spree::Country do
    transient do
      sequence(:iso_pool_index) { |n| n }
    end

    # A spec naming a country ("France") gets that country; otherwise the
    # sequence walks a pool of real codes so "some other country" still works.
    iso do
      requested_name = @overrides && (@overrides[:name] || @overrides['name'])
      named = requested_name.present? ? ISO3166::Country.find_country_by_any_name(requested_name) : nil
      named&.alpha2 || Spree::TestingSupport::CountryPool.iso_for(iso_pool_index)
    end

    skip_create
    initialize_with { Spree::Country.by_iso(iso) }

    factory :country_us, class: Spree::Country, parent: :country do
      iso { 'US' }
    end
  end
end
