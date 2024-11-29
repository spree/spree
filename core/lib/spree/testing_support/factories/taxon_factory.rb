FactoryBot.define do
  factory :taxon, class: Spree::Taxon do
    sequence(:name) { |n| "taxon_#{n}" }

    association :taxonomy, strategy: :create
    association :icon, factory: :taxon_image
    parent_id { taxonomy.root.id }

    trait :with_description do
      description { '<div>Test <strong>description</strong></div>' }
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
