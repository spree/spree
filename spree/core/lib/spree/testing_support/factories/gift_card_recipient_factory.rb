FactoryBot.define do
  factory :gift_card_recipient, class: Spree::GiftCardRecipient do
    email { 'friend@example.com' }
    name { 'Alex' }
    message { 'Happy birthday!' }
    line_item { association :line_item, product: create(:gift_card_product) }
  end
end
