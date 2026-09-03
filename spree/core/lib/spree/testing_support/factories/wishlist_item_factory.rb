FactoryBot.define do
  factory :wishlist_item, class: Spree::WishlistItem do
    variant
    wishlist
  end

  # Renamed in 6.0; the old name is kept for one release so extension suites
  # keep building.
  factory :wished_item, parent: :wishlist_item
end
