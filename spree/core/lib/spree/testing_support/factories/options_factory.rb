FactoryBot.define do
  factory :option_value, class: Spree::OptionValue do
    sequence(:name) { |n| "Size-#{n}" }
    label    { 'S' }
    option_type
  end

  factory :option_value_variant, class: Spree::OptionValueVariant do
    option_value
    variant
  end

  factory :option_type, class: Spree::OptionType do
    sequence(:name) { |n| "foo-size-#{n}" }
    label    { 'Size' }

    trait :size do
      name { 'size' }
      label { 'Size' }
    end

    trait :color do
      name { 'color' }
      label { 'Color' }
      kind { 'color_swatch' }
    end

    trait :color_swatch do
      name { 'color' }
      label { 'Color' }
      kind { 'color_swatch' }
    end

    trait :buttons do
      kind { 'buttons' }
    end
  end
end
