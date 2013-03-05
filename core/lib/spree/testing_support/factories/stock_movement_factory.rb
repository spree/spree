FactoryGirl.define do
  factory :stock_movement, :class => Spree::StockMovement do
    quantity 1

    # associations:
    stock_item
  end

  trait :sold do
    action 'sold'
  end

  trait :received do
    action 'received'
  end
end
