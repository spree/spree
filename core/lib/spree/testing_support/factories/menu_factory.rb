FactoryBot.define do
  factory :menu, class: Spree::Menu do
    name { generate(:random_string) }
    unique_code { generate(:random_string) }
  end
end
