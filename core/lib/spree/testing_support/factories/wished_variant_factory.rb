FactoryBot.define do
  factory :wished_variant, class: Spree::WishedVariant do
    variant
    wishlist
  end
end
