FactoryBot.define do
  factory :property, class: Spree::Property do
    sequence(:name) { |n| "baseball_cap_color_#{n}" }
    presentation { 'cap color' }

    trait :filterable do
      filterable { true }
    end

    trait :brand do
      sequence(:name) { |n| "brand-#{n}" }
      presentation { 'Brand' }
      filter_param { 'brand' }
    end

    trait :manufacturer do
      sequence(:name) { |n| "manufacturer-#{n}" }
      presentation { 'Manufacturer' }
      filter_param { 'manufacturer' }
    end

    trait :material do
      sequence(:name) { |n| "material-#{n}" }
      presentation { 'Material' }
      filter_param { 'material' }
    end
  end
end
