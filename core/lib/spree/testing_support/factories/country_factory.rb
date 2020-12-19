# frozen_string_literal: true

require 'carmen'

FactoryBot.define do
  factory :country, class: 'Spree::Country' do
    iso { 'US' }

    transient do
      carmen_country { Carmen::Country.coded(iso) || fail("Unknown country iso code: #{iso.inspect}") }
    end

    iso_name { carmen_country.name.upcase }
    name { carmen_country.name }
    iso3 { carmen_country.alpha_3_code }
    numcode { carmen_country.numeric_code }
  end
end
