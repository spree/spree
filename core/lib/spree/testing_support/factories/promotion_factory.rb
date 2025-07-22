FactoryBot.define do
  trait :with_item_total_rule do
    transient do
      item_total_threshold_amount { 10 }
    end

    after(:create) do |promotion, evaluator|
      Spree::Promotion::Rules::ItemTotal.create!(
        promotion: promotion,
        preferred_operator_min: 'gte',
        preferred_operator_max: 'lte',
        preferred_amount_min: evaluator.item_total_threshold_amount,
        preferred_amount_max: evaluator.item_total_threshold_amount + 100
      )
    end
  end

  factory :promotion, class: Spree::Promotion do
    name { 'Promo' }
    sequence :code do |n|
      "CODE-#{n}"
    end

    before(:create) do |promotion, _evaluator|
      if promotion.stores.empty?
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        promotion.stores << [store]
      end
    end

    trait :with_line_item_adjustment do
      transient do
        adjustment_rate { 10 }
      end

      after(:create) do |promotion, evaluator|
        calculator = Spree::Calculator::FlatRate.new
        calculator.preferred_amount = evaluator.adjustment_rate
        Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promotion)
      end
    end

    trait :with_one_use_per_user_rule do
      after(:create) do |promotion|
        rule = Spree::Promotion::Rules::OneUsePerUser.create!
        promotion.rules << rule
      end
    end

    factory :promotion_with_item_adjustment, traits: [:with_line_item_adjustment]
    factory :promotion_with_one_use_per_user_rule, traits: [:with_line_item_adjustment, :with_one_use_per_user_rule]

    trait :with_order_adjustment do
      transient do
        weighted_order_adjustment_amount { 10 }
      end

      after(:create) do |promotion, evaluator|
        calculator = Spree::Calculator::FlatRate.new
        calculator.preferred_amount = evaluator.weighted_order_adjustment_amount
        Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promotion)
      end
    end

    factory :promotion_with_order_adjustment, traits: [:with_order_adjustment]
    factory :promotion_with_item_total_rule, traits: [:with_item_total_rule]

    factory :free_shipping_promotion do
      name { 'Free Shipping Promotion' }

      after(:create) do |promotion|
        Spree::Promotion::Actions::FreeShipping.create!(promotion: promotion)
      end

      factory :free_shipping_promotion_with_item_total_rule, traits: [:with_item_total_rule]
    end
  end
end
