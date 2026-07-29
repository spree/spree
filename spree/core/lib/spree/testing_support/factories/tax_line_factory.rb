FactoryBot.define do
  factory :tax_line, class: Spree::TaxLine do
    line_item { create(:order_with_line_items, line_items_count: 1).line_items.first }
    order { line_item&.order || fulfillment&.order || fee&.order }
    amount { 1.0 }
    rate { 0.05 }
    label { 'Tax 5%' }
    included { false }
    provider_id { 'internal' }
  end
end
