FactoryGirl.define do
  factory :order, :class => Spree::Order do
    # associations:
    association(:user, :factory => :user)
    association(:bill_address, :factory => :address)
    completed_at nil
    bill_address_id nil
    ship_address_id nil
    email 'foo@example.com'

    factory :order_with_totals, :parent => :order do
      after(:create) do |order|
        FactoryGirl.create(:line_item, :order => order)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :order_with_line_items do
      ignore do
        line_items_count 5
      end
      bill_address { FactoryGirl.create(:address) }
      ship_address { FactoryGirl.create(:address) }

      after(:create) do |order, evaluator|
        FactoryGirl.create(:shipment, :order => order)
        order.shipments.reload

        FactoryGirl.create_list(:line_item, evaluator.line_items_count, :order => order)
        order.line_items.reload
        order.update!
      end
    end

    factory :completed_order_with_totals, :parent => :order_with_line_items do
      bill_address { FactoryGirl.create(:address) }
      ship_address { FactoryGirl.create(:address) }
      state 'complete'
      completed_at Time.now

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
