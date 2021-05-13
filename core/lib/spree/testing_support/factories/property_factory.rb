FactoryBot.define do
  factory :property, class: Spree::Property do
    name         { 'baseball_cap_color' }
    presentation { 'cap color' }

    trait :brand do
      name         { 'brand' }
      presentation { 'Brand' }
      filter_param { 'brand' }
    end
  end
end
