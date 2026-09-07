FactoryBot.define do
  factory :purchase_order, class: Spree::PurchaseOrder do
    transient do
      # Zero opens an empty draft — what a merchant sees before adding a SKU.
      quantity { 10 }
      unit_cost { 12.5 }
    end

    store { Spree::Store.default || create(:store) }
    supplier { create(:supplier, store: store) }
    destination_location { create(:stock_location, store: store) }
    status { Spree::PurchaseOrder.default_status }
    expected_at { 2.weeks.from_now.to_date }

    after(:build) do |purchase_order, evaluator|
      next if purchase_order.items.any? || evaluator.quantity.to_i.zero?

      purchase_order.items.build(
        variant: create(:variant),
        quantity_ordered: evaluator.quantity,
        unit_cost: evaluator.unit_cost
      )
    end

    trait :ordered do
      after(:create) do |purchase_order|
        Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)
        purchase_order.reload
      end
    end

    trait :received do
      ordered

      after(:create) do |purchase_order|
        Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order)
        purchase_order.reload
      end
    end
  end

  factory :purchase_order_item, class: Spree::PurchaseOrderItem do
    purchase_order
    variant
    quantity_ordered { 10 }
    quantity_received { 0 }
    unit_cost { 12.5 }
  end
end
