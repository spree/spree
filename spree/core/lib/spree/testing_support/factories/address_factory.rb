FactoryBot.define do
  factory :address, aliases: [:bill_address, :ship_address], class: Spree::Address do
    firstname         { 'John' }
    lastname          { 'Doe' }
    company           { 'Company' }
    sequence(:address1) { |n| "#{n} Lovely Street" }
    address2          { 'Northwest' }
    city              { 'New York' }
    zipcode           { '10118' }
    phone             { '555-555-0199' }
    alternative_phone { '555-555-0199' }

    # Default to a real US/NY pair (cached via find_or_create_by) so generated
    # OpenAPI examples carry plausible country/state fields. Tests that need a
    # different state/country pass them explicitly.
    country do
      Spree::Country.find_or_create_by!(iso: 'US') do |c|
        c.iso3 = 'USA'
        c.name = 'United States of America'
        c.iso_name = 'UNITED STATES'
        c.numcode = 840
        c.states_required = true
      end
    end

    state do |address|
      (address.country || Spree::Country.find_by(iso: 'US'))&.states&.find_or_create_by!(abbr: 'NY') { |s| s.name = 'New York' }
    end
  end
end
