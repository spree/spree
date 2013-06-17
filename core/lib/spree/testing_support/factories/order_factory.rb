FactoryGirl.define do
  factory :order, class: Spree::Order do
    user
    bill_address
    completed_at nil
    email { user.email }

    factory :order_with_totals do
      after(:create) do |order|
        create(:line_item, order: order)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :order_with_line_items do
      bill_address
      ship_address

      ignore do
        line_items_count 5
      end

      after(:create) do |order, evaluator|
        create(:shipment, order: order)
        order.shipments.reload

        create_list(:line_item, evaluator.line_items_count, order: order)
        order.line_items.reload
        order.update!
      end

      factory :completed_order_with_totals do
        state 'complete'
        completed_at { Time.now }

        factory :order_ready_to_ship do
          payment_state 'paid'
          shipment_state 'ready'
          after(:create) do |order|
            create(:payment, amount: order.total, order: order, state: 'completed')
            order.shipments.each do |shipment|
              shipment.inventory_units.each { |u| u.update_attribute('state', 'on_hand') }
              shipment.update_attribute('state', 'ready')
            end
            order.reload
          end
        end

        factory :shipped_order do
          after(:create) do |order|
            order.shipments.each do |shipment|
              shipment.inventory_units.each { |u| u.update_attribute('state', 'shipped') }
              shipment.update_attribute('state', 'shipped')
            end
            order.reload
          end
        end
      end
    end
  end
end
