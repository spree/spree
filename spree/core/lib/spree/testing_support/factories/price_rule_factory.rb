FactoryBot.define do
  factory :price_rule, class: Spree::PriceRule do
    price_list

    factory :zone_price_rule, class: Spree::PriceRules::ZoneRule do
      after(:build) do |rule, evaluator|
        rule.preferred_zone_ids = evaluator.zone_ids if evaluator.respond_to?(:zone_ids)
      end

      transient do
        zone_ids { [] }
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

    factory :user_price_rule, class: Spree::PriceRules::UserRule do
      after(:build) do |rule, evaluator|
        rule.preferred_user_ids = evaluator.user_ids if evaluator.respond_to?(:user_ids)
      end

      transient do
        user_ids { [] }
      end
    end

    factory :customer_group_price_rule, class: Spree::PriceRules::CustomerGroupRule do
      after(:build) do |rule, evaluator|
        rule.preferred_customer_group_ids = evaluator.customer_group_ids if evaluator.respond_to?(:customer_group_ids)
      end

      transient do
        customer_group_ids { [] }
      end
    end

    factory :market_price_rule, class: Spree::PriceRules::MarketRule do
      after(:build) do |rule, evaluator|
        rule.preferred_market_ids = evaluator.market_ids if evaluator.respond_to?(:market_ids)
      end

      transient do
        market_ids { [] }
      end
    end
  end
end
