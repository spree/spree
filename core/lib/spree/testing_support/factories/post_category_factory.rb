FactoryBot.define do
  factory :post_category, class: Spree::PostCategory do
    sequence(:title) { |n| "Category ##{n + 1}" }
    description { FFaker::Lorem.sentence }
    store { Spree::Store.default || create(:store) }
  end
end
