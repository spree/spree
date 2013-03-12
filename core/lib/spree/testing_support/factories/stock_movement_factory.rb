FactoryGirl.define do
  factory :stock_movement, :class => Spree::StockMovement do
    quantity 1
    action 'sold'

    # associations:
    stock_item
  end

  trait :received do
    action 'received'
  end
end
