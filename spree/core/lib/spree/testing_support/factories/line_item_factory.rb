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
      # The product must live in the owning cart/order's store — a cart can
      # only sell its own store's catalog, and delivery eligibility resolves
      # through the product's store-scoped delivery profile.
      owner_store = (order || cart)&.store
      resolved_product = product || create(:product, store: owner_store || Spree::Store.default)
      resolved_product.default_variant
    end
  end
end
