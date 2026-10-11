FactoryBot.define do
  factory :line_item_gift, class: Spree::LineItemGift do
    line_item
    association :promotion_action, factory: :promotion_action_create_line_items
    quantity { 1 }
  end
end
