FactoryGirl.define do
  # must use build()
  factory :stock_packer, class: Spree::Stock::Packer do
    ignore do
      stock_location { build(:stock_location) }
      contents []
    end

    initialize_with { new(stock_location, contents) }
  end

  factory :stock_package, class: Spree::Stock::Package do
    ignore do
      stock_location { build(:stock_location) }
      order { create(:order_with_line_items, line_items_count: 2) }
      contents []
    end

    initialize_with { new(stock_location, order, contents) }

    factory :stock_package_fulfilled do
      after(:build) do |package, evaluator|
        evaluator.order.line_items.reload
        evaluator.order.line_items.each do |line_item|
          package.add line_item.variant, line_item.quantity, :on_hand
        end
      end
    end
  end
end
