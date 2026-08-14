FactoryBot.define do
  factory :tax_line, class: Spree::TaxLine do
    line_item { create(:order_with_line_items, line_items_count: 1).line_items.first }
    order { line_item&.order || fulfillment&.order || fee&.order }
    amount { 1.0 }
    rate { 0.05 }
    label { 'Tax 5%' }
    included { false }
    provider_id { 'internal' }

    # Tax written during checkout, before the cart becomes an order. The owner
    # is exactly one of cart/order, so the order FK has to be cleared.
    trait :on_cart do
      line_item { create(:cart_with_line_items, line_items_count: 1).line_items.first }
      order { nil }
      cart { line_item.cart }
    end
  end
end
