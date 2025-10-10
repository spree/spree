FactoryBot.define do
  # for the case when you want to supply existing return items instead of generating some
  factory :customer_return_without_return_items, class: Spree::CustomerReturn do
    association(:stock_location, factory: :stock_location)

    before(:create) do |customer_return, _evaluator|
      if customer_return.store.nil?
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        customer_return.store = store
      end
    end

    factory :customer_return, class: Spree::CustomerReturn do
      transient do
        line_items_count   { 1 }
        return_items_count { line_items_count }
      end

      before(:create) do |customer_return, evaluator|
        shipped_order = create(:shipped_order, line_items_count: evaluator.line_items_count, store: customer_return.store)

        shipped_order.inventory_units.take(evaluator.return_items_count).each do |inventory_unit|
          customer_return.return_items << build(:return_item, inventory_unit: inventory_unit)
        end
      end

      factory :customer_return_with_accepted_items do
        after(:create) do |customer_return|
          customer_return.return_items.each(&:accept!)
        end
      end
    end
  end
end
