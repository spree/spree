FactoryBot.define do
  factory :preference, class: Spree::Preference do
    sequence(:key) { |n| "preference/#{n}" }
    value { 'value' }
  end
end
