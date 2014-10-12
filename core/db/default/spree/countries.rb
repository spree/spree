require 'carmen'

countries = []
Carmen::Country.all.each do |country|
  countries << {
    name: country.name,
    iso3: country.alpha_3_code,
    iso: country.alpha_2_code,
    iso_name: country.name.upcase,
    numcode: country.numeric_code,
    states_required: country.subregions?
  }
end

ActiveRecord::Base.transaction do
  Spree::Country.create!(countries)
end

Spree::Config[:default_country_id] = Spree::Country.find_by(name: "United States").id
