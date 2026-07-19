FactoryBot.define do
  factory :collection, class: Spree::Collection do
    sequence(:name) { |n| "collection_#{n}" }
    store { Spree::Store.default }

    trait :with_description do
      description { '<div>Test <strong>description</strong></div>' }
    end

    trait :with_image do
      after(:create) do |collection|
        collection.image.attach(io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')), filename: 'thinking-cat.jpg')
      end
    end
  end

  factory :automatic_collection, parent: :collection do
    automatic { true }
    rules_match_policy { 'all' }

    trait :any_match_policy do
      rules_match_policy { 'any' }
    end
  end
end
