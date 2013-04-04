FactoryGirl.define do
  factory :order, class: Spree::Order do
    user
    bill_address
    completed_at nil
    bill_address_id nil
    ship_address_id nil
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
        # bill_address
        # ship_address
        state 'complete'
        completed_at { Time.now }

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
