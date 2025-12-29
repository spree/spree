FactoryBot.define do
  factory :price_rule, class: Spree::PriceRule do
    price_list
    priority { 0 }

    factory :store_price_rule, class: Spree::PriceRules::StoreRule do
      after(:build) do |rule, evaluator|
        rule.preferred_store_ids = evaluator.store_ids if evaluator.respond_to?(:store_ids)
      end

      transient do
        store_ids { [] }
      end
    end

    factory :zone_price_rule, class: Spree::PriceRules::ZoneRule do
      after(:build) do |rule, evaluator|
        rule.preferred_zone_ids = evaluator.zone_ids if evaluator.respond_to?(:zone_ids)
      end

      transient do
        zone_ids { [] }
      end
    end

    factory :date_range_price_rule, class: Spree::PriceRules::DateRangeRule do
      after(:build) do |rule, evaluator|
        rule.preferred_starts_at = evaluator.starts_at if evaluator.starts_at.present?
        rule.preferred_ends_at = evaluator.ends_at if evaluator.ends_at.present?
      end

      transient do
        starts_at { nil }
        ends_at { nil }
      end
    end

    factory :volume_price_rule, class: Spree::PriceRules::VolumeRule do
      after(:build) do |rule, evaluator|
        rule.preferred_min_quantity = evaluator.min_quantity if evaluator.min_quantity.present?
        rule.preferred_max_quantity = evaluator.max_quantity if evaluator.max_quantity.present?
        rule.preferred_apply_to = evaluator.apply_to if evaluator.apply_to.present?
      end

      transient do
        min_quantity { nil }
        max_quantity { nil }
        apply_to { nil }
      end
    end

    factory :product_taxon_price_rule, class: Spree::PriceRules::ProductTaxonRule do
      after(:build) do |rule, evaluator|
        rule.preferred_taxon_ids = evaluator.taxon_ids if evaluator.respond_to?(:taxon_ids)
        rule.preferred_include_descendants = evaluator.include_descendants if evaluator.respond_to?(:include_descendants)
      end

      transient do
        taxon_ids { [] }
        include_descendants { true }
      end
    end

    factory :user_price_rule, class: Spree::PriceRules::UserRule do
      after(:build) do |rule, evaluator|
        rule.preferred_user_ids = evaluator.user_ids if evaluator.respond_to?(:user_ids)
      end

      transient do
        user_ids { [] }
      end
    end
  end
end
