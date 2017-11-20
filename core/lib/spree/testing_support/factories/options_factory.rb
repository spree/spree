FactoryBot.define do
  factory :option_value, class: Spree::OptionValue do
    sequence(:name) { |n| "Size-#{n}" }

    presentation 'S'
    option_type
  end

  factory :option_type, class: Spree::OptionType do
    sequence(:name) { |n| "foo-size-#{n}" }
    presentation 'Size'
  end
end
