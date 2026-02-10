FactoryBot.define do
  factory :option_value, class: Spree::OptionValue do
    sequence(:name) { |n| "Size-#{n}" }
    presentation    { 'S' }
    option_type
  end

  factory :option_value_variant, class: Spree::OptionValueVariant do
    option_value
    variant
  end

  factory :option_type, class: Spree::OptionType do
    sequence(:name) { |n| "foo-size-#{n}" }
    presentation    { 'Size' }

    trait :size do
      name { 'size' }
      presentation { 'Size' }
    end

    trait :color do
      name { 'color' }
      presentation { 'Color' }
    end
  end
end
