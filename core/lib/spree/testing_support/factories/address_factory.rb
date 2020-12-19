FactoryBot.define do
  factory :address, aliases: [:bill_address, :ship_address], class: Spree::Address do

    transient do
      country_iso_code { 'US' }
      state_code { 'AL' }
    end

    firstname         { 'John' }
    lastname          { 'Doe' }
    company           { 'Company' }
    address1          { '10 Lovely Street' }
    address2          { 'Northwest' }
    city              { 'Herndon' }
    zipcode           { '35005' }
    phone             { '555-555-0199' }
    alternative_phone { '555-555-0199' }

    state { |address| address.association(:state) || Spree::State.last }

    country do |address|
      if address.state
        address.state.country
      else
        address.association(:country, iso: country_iso_code)
      end
    end
  end
end
