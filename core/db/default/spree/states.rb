Spree::Country.where(states_required: true).each do |country|
  carmen_country = Carmen::Country.named(country.name)
  next unless carmen_country

  carmen_country.subregions.each do |subregion|
    if subregion.subregions?
      subregion.subregions.each do |province|
        country.states.where(
          name: province.name,
          abbr: province.code,
          country_id: country.id
        ).first_or_create
      end
    else
      country.states.where(
        name: subregion.name,
        abbr: subregion.code,
        country_id: country.id
      ).first_or_create
    end
  end
end
