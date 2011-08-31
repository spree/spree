FactoryGirl.define do
  factory :option_value do
    name 'Size'
    presentation 'S'
    association :option_type
  end

  factory :option_type do
    name 'foo-size'
    presentation 'Size'
  end
end