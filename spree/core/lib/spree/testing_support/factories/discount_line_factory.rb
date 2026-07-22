FactoryBot.define do
  # Defaults to a manual discount line (no promotion action); use
  # :from_promotion for a promotion-backed row.
  factory :discount_line, class: Spree::DiscountLine do
    line_item
    order { line_item&.order || fulfillment&.order }

    amount { -10.0 }
    label { 'Manual discount' }
    kind { 'manual' }

    trait :from_promotion do
      kind { nil }
      association(:promotion_action, factory: :promotion_action_create_adjustment)
      promotion { promotion_action.promotion }
      label { promotion.name }
    end

    trait :for_fulfillment do
      line_item { nil }
      association(:fulfillment, factory: :shipment)
    end
  end
end
