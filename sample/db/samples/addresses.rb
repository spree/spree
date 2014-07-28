country = Spree::Country.find_by_name!("Israel")
state = Spree::State.find_by_name!("ירושלים")

# Billing address
Spree::Address.create!(
  :firstname => Faker::Name.first_name,
  :lastname => Faker::Name.last_name,
  :address1 => Faker::Address.street_address,
  :address2 => Faker::Address.secondary_address,
  :city => Faker::Address.city,
  :state => state,
  :zipcode => 16804,
  :country => country,
  :phone => Faker::PhoneNumber.phone_number)

#Shipping address
Spree::Address.create!(
  :firstname => Faker::Name.first_name,
  :lastname => Faker::Name.last_name,
  :address1 => Faker::Address.street_address,
  :address2 => Faker::Address.secondary_address,
  :city => Faker::Address.city,
  :state => state,
  :zipcode => 16804,
  :country => country,
  :phone => Faker::PhoneNumber.phone_number)
