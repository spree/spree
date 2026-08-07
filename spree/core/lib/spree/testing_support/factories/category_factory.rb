FactoryBot.define do
  factory :category, class: Spree::Category do
    sequence(:name) { |n| "category_#{n}" }

    store { Spree::Store.default }
    parent { nil }

    trait :with_description do
      description { '<div>Test <strong>description</strong></div>' }
    end

    trait :with_header_image do
      after(:create) do |category|
        category.image.attach(io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')), filename: 'thinking-cat.jpg')
      end
    end
  end
end
