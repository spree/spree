FactoryBot.define do
  factory :promotion, class: Spree::Promotion do
    name 'Promo'

    trait :with_line_item_adjustment do
      transient do
        adjustment_rate 10
      end

      after(:create) do |promotion, evaluator|
        calculator = Spree::Calculator::FlatRate.new
        calculator.preferred_amount = evaluator.adjustment_rate
        Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promotion)
      end
    end
    factory :promotion_with_item_adjustment, traits: [:with_line_item_adjustment]

    trait :with_order_adjustment do
      transient do
        weighted_order_adjustment_amount 10
      end

      after(:create) do |promotion, evaluator|
        calculator = Spree::Calculator::FlatRate.new
        calculator.preferred_amount = evaluator.weighted_order_adjustment_amount
        action = Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator)
        promotion.actions << action
        promotion.save!
      end
    end
    factory :promotion_with_order_adjustment, traits: [:with_order_adjustment]

    trait :with_item_total_rule do
      transient do
        item_total_threshold_amount 10
      end

      after(:create) do |promotion, evaluator|
        rule = Spree::Promotion::Rules::ItemTotal.create!(
          preferred_operator_min: 'gte',
          preferred_operator_max: 'lte',
          preferred_amount_min: evaluator.item_total_threshold_amount,
          preferred_amount_max: evaluator.item_total_threshold_amount + 100
        )
        promotion.rules << rule
        promotion.save!
      end
    end
    factory :promotion_with_item_total_rule, traits: [:with_item_total_rule]
  end
end
