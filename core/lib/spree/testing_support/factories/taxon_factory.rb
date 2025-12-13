FactoryBot.define do
  factory :taxon, class: Spree::Taxon do
    sequence(:name) { |n| "taxon_#{n}" }

    association :taxonomy, strategy: :create
    parent_id { taxonomy.root.id }

    trait :with_description do
      description { '<div>Test <strong>description</strong></div>' }
    end

    trait :with_header_image do
      after(:create) do |taxon|
        taxon.image.attach(io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')), filename: 'thinking-cat.jpg')
      end
    end
  end

  factory :automatic_taxon, parent: :taxon do
    automatic { true }
    rules_match_policy { :all }

    trait :any_match_policy do
      rules_match_policy { :any }
    end
  end
end
