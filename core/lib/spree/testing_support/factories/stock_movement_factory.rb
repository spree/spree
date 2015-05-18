FactoryGirl.define do
  factory :stock_movement, class: Spree::StockMovement do
    quantity 1
    action 'sold'
    stock_item { create(:variant).stock_items.first! }
  end

  trait :received do
    action 'received'
  end
end
