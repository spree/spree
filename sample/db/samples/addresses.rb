ukraine = Spree::Country.find_by!(iso: 'UA')
states = %w[Вінницька Волинська Дніпропетровська Донецька Житомирська Закарпатська Запорізька Івано-Франківська Київська Кіровоградська Луганська Львівська Миколаївська Одеська Полтавська Рівненська Сумська Тернопільська Харківська Херсонська Хмельницька Черкаська Чернівецька Чернігівська]

states.each do |state|
  Spree::State.where(
    name: state,
    country_id: ukraine.id
  ).first_or_create!
end
kyiv = Spree::State.find_by!(name: "Київська")

# Billing address
Spree::Address.create!(
  firstname: FFaker::NameUA.first_name,
  lastname: FFaker::NameUA.last_name,
  address1: FFaker::AddressUA.street_address,
  address2: "Квартира #{FFaker::AddressUA.building_number}",
  city: FFaker::AddressUA.city,
  state: kyiv,
  zipcode: FFaker::AddressUA.zip_code,
  country: ukraine,
  phone: FFaker::PhoneNumberUA.phone_number
)

# Shipping address
Spree::Address.create!(
  firstname: FFaker::NameUA.first_name,
  lastname: FFaker::NameUA.last_name,
  address1: FFaker::AddressUA.street_address,
  address2: "Квартира #{FFaker::AddressUA.building_number}",
  city: FFaker::AddressUA.city,
  state: kyiv,
  zipcode: FFaker::AddressUA.zip_code,
  country: ukraine,
  phone: FFaker::PhoneNumberUA.phone_number
)
