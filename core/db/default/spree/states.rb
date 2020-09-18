# frozen_string_literal: true

EXCLUDED_US_STATES = ['UM', 'AS', 'MP', 'VI', 'PR', 'GU'].freeze
EXCLUDED_CN_STATES = ['HK', 'MO', 'TW'].freeze

def state_level(country, subregion)
  country.states.where(
    name: subregion.name,
    abbr: subregion.code
  ).first_or_create
end

def province_level(country, subregion)
  subregion.subregions.each do |province|
    country.states.where(
      name: province.name,
      abbr: province.code
    ).first_or_create
  end
end

Spree::Country.where(states_required: true).each do |country|
  carmen_country = Carmen::Country.named(country.name)
  next unless carmen_country

  carmen_country.subregions.each do |subregion|
    if carmen_country.alpha_2_code == 'US'
      # Produces 50 states, one postal district (Washington DC)
      # and 3 APO's as you would expect to see on any good U.S. states list.
      next if EXCLUDED_US_STATES.include?(subregion.code)

      state_level(country, subregion)
    elsif carmen_country.alpha_2_code == 'CA' || carmen_country.alpha_2_code == 'MX'
      # Force Canada and Mexico to use state-level data import from Carmen Gem
      # else we pull in a subset of provinces that are not common at checkout.
      state_level(country, subregion)
    elsif carmen_country.alpha_2_code == 'CN'
      # Removes 3 "States" from that list that are also listed as Countries,
      # Hong Kong, Taiwan and Macao
      next if EXCLUDED_CN_STATES.include?(subregion.code)

      state_level(country, subregion)
    elsif subregion.subregions?
      province_level(country, subregion)
    else
      state_level(country, subregion)
    end
  end
end
