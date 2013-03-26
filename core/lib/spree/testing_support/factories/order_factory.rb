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
        FactoryGirl.create_list(:line_item, evaluator.line_items_count, :order => order)
        order.line_items.reload
      end
    end

    factory :completed_order_with_totals do
      bill_address { FactoryGirl.create(:address) }
      ship_address { FactoryGirl.create(:address) }
      state 'complete'
      completed_at Time.now

      after(:create) do |order|
        shipment = FactoryGirl.create(:shipment, :order => order)
        shipment.add(FactoryGirl.create(:variant), 3)
      end
    end
  end

end
