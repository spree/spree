FactoryBot.define do
  factory :stock_movement, class: Spree::StockMovement do
    quantity { 1 }
    kind { 'received' }
    stock_level
  end

  trait :received do
    kind { 'received' }
  end

  trait :allocated do
    kind { 'allocated' }
  end

  trait :shipped do
    kind { 'shipped' }
  end

  trait :released do
    kind { 'released' }
  end

  trait :adjusted do
    kind { 'adjusted' }
    reason { 'Manual adjustment' }
  end
end
