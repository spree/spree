FactoryGirl.define do
  factory :customer_return, class: Spree::CustomerReturn do
    association(:stock_location, factory: :stock_location)
    factory :customer_return_with_return_items do
      before(:create) do |customer_return, evaluator|
        shipped_order = create(:shipped_order)
        customer_return.return_items << create(:return_item, inventory_unit: create(:inventory_unit, state: 'shipped', order: shipped_order))
        customer_return.return_items << create(:return_item, inventory_unit: create(:inventory_unit, state: 'shipped', order: shipped_order))
      end
    end
  end
end
