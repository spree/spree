FactoryBot.define do
  factory :collection, class: Spree::Collection do
    sequence(:name) { |n| "collection_#{n}" }
    store { Spree::Store.default }

    # Mirrors Spree.collection_create_workflow: live on every active channel
    # unless the attributes carry a publications set.
    transient do
      published { true }
    end

    after(:create) do |collection, evaluator|
      next unless evaluator.published && !collection.publications_assigned?

      collection.store.channels.active.publish_records(Spree::Collection, collection.id, publish_events: false)
      collection.publications.reset
    end

    trait :unpublished do
      published { false }
    end

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
