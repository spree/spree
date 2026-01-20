FactoryBot.define do
  factory :line_item, class: Spree::LineItem do
    order
    quantity { 1 }
    price    { BigDecimal('10.00') }
    currency { order.currency }

    transient do
      create_stock { true }
    end

    product do
      stores = order&.store&.present? ? [order.store] : [Spree::Store.default]
      create(:product, stores: stores, create_stock: create_stock)
    end
    variant { product.master }
  end
end
