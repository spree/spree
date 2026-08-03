FactoryBot.define do
  factory :line_item, class: Spree::LineItem do
    transient do
      product { nil }
    end

    order { cart.present? ? nil : create(:order) }
    quantity { 1 }
    price    { BigDecimal('10.00') }
    currency { (order || cart)&.currency }
    variant do
      resolved_product = product || create(:product)
      resolved_product.default_variant
    end
  end
end
