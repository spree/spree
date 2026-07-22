FactoryBot.define do
  factory :fee, class: Spree::Fee do
    line_item
    order { line_item&.order || fulfillment&.order }

    amount { 5.99 }
    label { 'Gift wrapping' }
    kind { 'gift_wrap' }

    trait :for_fulfillment do
      line_item { nil }
      association(:fulfillment, factory: :shipment)
    end
  end
end
