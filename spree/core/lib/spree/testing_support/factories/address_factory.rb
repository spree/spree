FactoryBot.define do
  factory :address, aliases: [:bill_address, :ship_address], class: Spree::Address do
    firstname         { 'John' }
    lastname          { 'Doe' }
    company           { 'Company' }
    sequence(:address1) { |n| "#{n} Lovely Street" }
    address2          { 'Northwest' }
    city              { 'New York' }
    phone             { '555-555-0199' }
    alternative_phone { '555-555-0199' }

    # A real US/NY pair, so generated OpenAPI examples carry plausible fields
    # and address validation has a subdivision it recognises. The model stores
    # plain codes; country/state stay as transient value objects so specs can
    # keep passing them (or country_code/state_code directly).
    transient do
      # The owner is polymorphic; these keep the customer case readable, since
      # a customer's address book is what most specs are building.
      customer { nil }
      user { nil }

      country { Spree::Country.by_iso('US') }

      # NY only when the country is actually the US — specs that pass a
      # different country get one of its own subdivisions instead of an
      # invalid pairing.
      state do
        if country.nil?
          nil
        elsif country.iso == 'US'
          create(:state, country: country, abbr: 'NY')
        else
          create(:state, country: country)
        end
      end
    end

    country_code { country&.iso }
    state_code { state&.abbr }

    # Countries now carry their real postal formats, so a US ZIP would be
    # rejected everywhere else. Specs that care about a particular code pass
    # one; the rest just need something the country accepts.
    zipcode { Spree::TestingSupport::CountryPool.postal_code_for(country&.iso) }

    after(:build) do |address, evaluator|
      owner = evaluator.customer || evaluator.user
      address.owner = owner if owner
    end

    # An address addressed to a business rather than a person. What it asks
    # for follows from its owner, so naming one is the whole difference.
    factory :business_address do
      association :owner, factory: :seller
      firstname { nil }
      lastname  { nil }
      company   { 'Acme Industrial' }
    end
  end
end
