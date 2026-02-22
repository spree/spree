FactoryBot.define do
  factory :customer_group, class: Spree::CustomerGroup do
    sequence(:name) { |n| "Customer Group #{n}" }
    store { Spree::Store.default || create(:store) }
  end
end
