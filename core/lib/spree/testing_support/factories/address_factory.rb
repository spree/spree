FactoryBot.define do
  factory :address, aliases: [:bill_address, :ship_address], class: Spree::Address do
    firstname         { 'John' }
    lastname          { 'Doe' }
    company           { 'Company' }
    sequence(:address1) { |n| "#{n} Lovely Street" }
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
        address.association(:country)
      end
    end
  end
end
