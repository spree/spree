FactoryBot.define do
  factory :country, class: Spree::Country do
    sequence(:iso_name) { |n| "ISO_NAME_#{n}" }
    sequence(:name)     { |n| "NAME_#{n}" }
    sequence(:iso)      { |n| "I#{n}" }
    sequence(:iso3)     { |n| "IS#{n}" }
    numcode             { 840 }

    factory :country_us, class: Spree::Country, parent: :country do
      iso { 'US' }
      iso3 { 'USA' }
      name { 'United States of America' }
      iso_name { 'UNITED STATES' }
      states_required { true }
    end
  end
end
