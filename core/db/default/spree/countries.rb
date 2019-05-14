require 'carmen'

if Spree::Country.all.blank?
  # populate only blank DB
  Spree::Country.create(
    Carmen::Country.all.map do |country|
      {
        name: country.name,
        iso3: country.alpha_3_code,
        iso: country.alpha_2_code,
        iso_name: country.name.upcase,
        numcode: country.numeric_code,
        states_required: country.subregions?
      }
    end
  )
end

Spree::Config[:default_country_id] = Spree::Country.find_by(iso: 'US').id

# find countries that do not use postal codes (by iso) and set 'zipcode_required' to false for them.

Spree::Country.where(iso: Spree::Address::NO_ZIPCODE_ISO_CODES).update_all(zipcode_required: false)
