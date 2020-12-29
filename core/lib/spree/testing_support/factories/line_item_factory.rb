FactoryBot.define do
  factory :line_item, class: Spree::LineItem do
    order
    quantity { 1 }
    price    { BigDecimal('10.00') }
    currency { order.currency }
    transient do
      association :product
    end
    variant { product.master }
  end
end
