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
      resolved_product = product || begin
        if order&.store&.present?
          create(:product, stores: [order.store])
        else
          create(:product)
        end
      end
      resolved_product.master
    end
  end
end
