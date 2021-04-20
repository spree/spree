FactoryBot.define do
  factory :menu, class: Spree::Menu do
    name { 'Main Menu' }
    unique_code { generate(:random_string) }
  end
end
