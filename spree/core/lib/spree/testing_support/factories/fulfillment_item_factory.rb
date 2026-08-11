FactoryBot.define do
  factory :fulfillment_item, aliases: [:inventory_unit], class: Spree::FulfillmentItem do
    variant
    order
    line_item
    status { 'on_hand' }

    association(:fulfillment, factory: :fulfillment, status: 'unfulfilled')

    # this trait usage increases build speed ~ 2x
    trait :without_assoc do
      fulfillment { nil }
      order       { nil }
      line_item   { nil }
    end
  end
end
