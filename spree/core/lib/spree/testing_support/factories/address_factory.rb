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
    # and address validation has a subdivision it recognises. Specs needing a
    # different place pass country/state (or country_iso/state_abbr) explicitly.
    country { Spree::Country.find_by(iso: 'US') || create(:country_us) }

    # NY only when the country is actually the US — specs that pass a different
    # country get one of its own subdivisions instead of an invalid pairing.
    state do
      if country.nil?
        nil
      elsif country.iso == 'US'
        create(:state, country: country, abbr: 'NY')
      else
        create(:state, country: country)
      end
    end

    # Countries now carry their real postal formats, so a US ZIP would be
    # rejected everywhere else. Specs that care about a particular code pass
    # one; the rest just need something the country accepts.
    zipcode { Spree::TestingSupport::CountryPool.postal_code_for(country&.iso) }
  end
end
