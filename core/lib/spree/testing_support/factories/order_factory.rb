FactoryGirl.define do
  factory :order, :class => Spree::Order do
    # associations:
    association(:user, :factory => :user)
    association(:bill_address, :factory => :address)
    completed_at nil
    bill_address_id nil
    ship_address_id nil
    email 'foo@example.com'

    factory :order_with_line_items do
      ignore do
        line_items_count 5
      end
      after(:create) do |order, evaluator|
        FactoryGirl.create_list(:line_item, evaluator.line_items_count, :order => order)
      end
    end

    factory :order_with_totals do
      after(:create) { |order| FactoryGirl.create(:line_item, :order => order) }
    end

    factory :order_with_inventory_unit_shipped do
      after(:create) do |order|
        FactoryGirl.create(:line_item, :order => order)
        FactoryGirl.create(:inventory_unit, :order => order, :state => 'shipped')
      end
    end

    factory :completed_order_with_totals do
      bill_address { FactoryGirl.create(:address) }
      ship_address { FactoryGirl.create(:address) }
      after(:create) do |order|
        FactoryGirl.create(:inventory_unit, :order => order, :state => 'shipped')
      end
      state 'complete'
      completed_at Time.now
    end
  end

end
