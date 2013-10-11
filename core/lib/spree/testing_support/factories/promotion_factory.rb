FactoryGirl.define do
  factory :promotion, class: Spree::Promotion do
    name 'Promo'

    factory :promotion_with_item_adjustment do
      ignore do
        adjustment_rate 10
      end

      after(:create) do |promotion, evaluator|
        calculator = Spree::Calculator::FlatRate.new
        calculator.preferred_amount = evaluator.adjustment_rate
        action = Spree::Promotion::Actions::CreateItemAdjustments.create(:calculator => calculator)
        promotion.actions << action
        promotion.save
      end
    end

  end
end
