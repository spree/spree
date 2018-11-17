Spree::Country.where(states_required: true).each do |country|
  carmen_country = Carmen::Country.named(country.name)
  next unless carmen_country

  carmen_country.subregions.each do |subregion|
    country.states.where(
      name: subregion.name,
      abbr: subregion.code,
      country_id: country.id
    ).first_or_create
  end
end
