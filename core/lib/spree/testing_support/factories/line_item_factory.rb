FactoryBot.define do
  factory :line_item, class: Spree::LineItem do
    order
    quantity { 1 }
    price    { BigDecimal('10.00') }
    currency { order.currency }
    product do
      if order&.store&.present?
        create(:product_in_stock, stores: [order.store])
      else
        create(:product_in_stock)
      end
    end
    variant { product.master }
  end
end
