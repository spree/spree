FactoryBot.define do
  factory :line_item, class: Spree::LineItem do
    order
    quantity { 1 }
    price    { BigDecimal('10.00') }
    currency { order.currency }
    transient do
      product { nil }
    end
    variant do
      resolved_product = product || create(:product)
      resolved_product.default_variant
    end
  end
end
