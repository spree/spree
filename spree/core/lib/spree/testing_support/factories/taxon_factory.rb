FactoryBot.define do
  # Legacy taxonomy-backed category, retained for the upgrade-path specs that
  # exercise the taxonomy severing migration. New specs use :category, which is
  # store-owned and creates no taxonomy. Removed in 6.1 with Spree::Taxonomy.
  factory :taxon, parent: :category do
    sequence(:name) { |n| "taxon_#{n}" }

    association :taxonomy, strategy: :create
    parent_id { taxonomy.root.id }
    # Overrides :category's default-store attribute — a taxonomy-backed category
    # belongs to whichever store owns its taxonomy. Specs that pass `taxonomy: nil`
    # to exercise inheritance from the parent fall back to the model's own
    # resolution.
    store { taxonomy&.store }
  end

  factory :automatic_taxon, parent: :taxon do
    automatic { true }
    rules_match_policy { :all }

    trait :any_match_policy do
      rules_match_policy { :any }
    end
  end
end
