FactoryGirl.define do
  factory :option_value, class: Spree::OptionValue do
    name 'Size'
    presentation 'S'
    option_type
  end

  factory :option_type, class: Spree::OptionType do
    name 'foo-size'
    presentation 'Size'
  end
end
