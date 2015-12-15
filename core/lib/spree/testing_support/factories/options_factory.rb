FactoryGirl.define do
  factory :option_value, class: Spree::OptionValue do
    sequence(:name,         &'Size-%d'.method(:%))
    sequence(:presentation, &'S-%d'.method(:%))

    option_type
  end

  factory :option_type, class: Spree::OptionType do
    sequence(:name,         &'foo-size-%d'.method(:%))
    sequence(:presentation, &'Size-%d'.method(:%))
  end
end
