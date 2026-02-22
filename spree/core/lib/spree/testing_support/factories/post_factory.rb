FactoryBot.define do
  factory :post, class: Spree::Post do
    store { Spree::Store.default || create(:store) }
    post_category { association(:post_category, store: store) }
    title { FFaker::Lorem.sentence }
    content { FFaker::Lorem.paragraph }
    published_at { Time.current }
    association :author, factory: :admin_user

    trait :with_image do
      image { Rack::Test::UploadedFile.new(Spree::Core::Engine.root.join('spec/fixtures/thinking-cat.jpg'), 'image/jpeg') }
    end

    trait :published do
      published_at { Time.current }
    end

    trait :unpublished do
      published_at { nil }
    end
  end
end
