Factory.define(:address) do |record|
  record.firstname  { Faker::Name.first_name }
  record.lastname   { Faker::Name.last_name }
  record.address1   { Faker::Address.street_address }
  record.address2   { Faker::Address.secondary_address }
  record.city       { Faker::Address.city }
  record.zipcode    { Faker::Address.zip_code }
  record.phone      { Faker::PhoneNumber.phone_number }
  record.state_name  { Faker::Address.us_state }
  record.alternative_phone { Faker::PhoneNumber.phone_number }
  
  #record.active true

  # associations: 
  record.country { 
    Country.find_by_id(Spree::Config[:default_country_id]) ||
      Country.find(:first) ||
      Factory(:country)
  }
end