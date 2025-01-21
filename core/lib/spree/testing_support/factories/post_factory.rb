FactoryBot.define do
  factory :post, class: Spree::Post do
    post_category { create(:post_category) }
    title { FFaker::Lorem.sentence }
    content { FFaker::Lorem.paragraph }
    published_at { Time.current }
    author { create(:admin_user) }
    store { Spree::Store.default || create(:store) }
  end
end
