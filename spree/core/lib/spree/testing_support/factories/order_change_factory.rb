FactoryBot.define do
  factory :order_change, class: Spree::OrderChange do
    association :order, factory: :completed_order_with_totals
    status { 'pending' }

    factory :requested_order_change do
      status { 'requested' }
      requested_at { Time.current }

      after(:create) do |order_change|
        line_item = order_change.order.line_items.first
        create(:order_change_action, order_change: order_change, kind: 'update_item',
                                     line_item: line_item, quantity: line_item.quantity + 1)
      end
    end
  end

  factory :order_change_action, class: Spree::OrderChangeAction do
    order_change
    kind { 'add_item' }
    variant
    quantity { 1 }
  end
end
