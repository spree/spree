require 'carmen'

countries = []
Carmen::Country.all.each do |country|
  countries << {
    name: country.name,
    iso3: country.alpha_3_code,
    iso: country.alpha_2_code,
    iso_name: country.name.upcase,
    numcode: country.numeric_code
  }
end

Spree::Country.create!(countries)

Spree::Config[:default_country_id] = Spree::Country.find_by(name: "United States").id
