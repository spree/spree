FactoryBot.define do
  factory :post, class: Spree::Post do
    post_category { create(:post_category, store: Spree::Store.default || create(:store)) }
    title { FFaker::Lorem.sentence }
    content { FFaker::Lorem.paragraph }
    published_at { Time.current }
    author { create(:admin_user) }
    store { Spree::Store.default || create(:store) }

    trait :with_image do
      image { Rack::Test::UploadedFile.new(Spree::Core::Engine.root.join('spec/fixtures/thinking-cat.jpg'), 'image/jpeg') }
    end
  end
end
