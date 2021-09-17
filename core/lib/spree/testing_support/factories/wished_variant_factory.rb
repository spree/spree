FactoryBot.define do
  factory :wished_item, class: Spree::WishedItem do
    variant
    wishlist
  end
end
