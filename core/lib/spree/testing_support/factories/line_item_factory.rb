FactoryGirl.define do
  factory :line_item, class: Spree::LineItem do
    quantity 1
    price { BigDecimal.new('10.00') }
    order
    variant
  end
end
