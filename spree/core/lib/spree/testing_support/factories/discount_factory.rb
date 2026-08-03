FactoryBot.define do
  factory :discount, class: Spree::Discount do
    line_item { fulfillment ? nil : create(:order_with_line_items, line_items_count: 1).line_items.first }
    order { line_item&.order || fulfillment&.order }
    amount { -5.0 }
    label { 'Discount' }
    kind { 'manual' }
  end
end
