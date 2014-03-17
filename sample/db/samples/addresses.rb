united_states = 'US'
new_york = 'NY'

# Billing address
Spree::Address.create!(
  :firstname => Faker::Name.first_name,
  :lastname => Faker::Name.last_name,
  :address1 => Faker::Address.street_address,
  :address2 => Faker::Address.secondary_address,
  :city => Faker::Address.city,
  :region_code => new_york,
  :zipcode => 16804,
  :country_code => united_states,
  :phone => Faker::PhoneNumber.phone_number)

#Shipping address
Spree::Address.create!(
  :firstname => Faker::Name.first_name,
  :lastname => Faker::Name.last_name,
  :address1 => Faker::Address.street_address,
  :address2 => Faker::Address.secondary_address,
  :city => Faker::Address.city,
  :region_code => new_york,
  :zipcode => 16804,
  :country_code => united_states,
  :phone => Faker::PhoneNumber.phone_number)
