FactoryBot.define do
  # No store attribute: Category#ensure_store resolves one from the parent, the
  # taxonomy, or the current store — so a child lands in its parent's store
  # rather than being forced into the default.
  factory :category, class: Spree::Category do
    sequence(:name) { |n| "category_#{n}" }

    parent { nil }

    # Mirrors Spree.category_create_workflow: live on every active channel
    # unless the attributes carry a publications set.
    transient do
      published { true }
    end

    after(:create) do |category, evaluator|
      next unless evaluator.published && !category.publications_assigned?

      category.store.channels.active.publish_records(Spree::Category, category.id, publish_events: false)
      category.publications.reset
    end

    trait :unpublished do
      published { false }
    end

    trait :with_description do
      description { '<div>Test <strong>description</strong></div>' }
    end

    trait :with_header_image do
      after(:create) do |category|
        category.image.attach(io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')), filename: 'thinking-cat.jpg')
        category.save!
      end
    end
  end
end
