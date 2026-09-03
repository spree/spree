class RenameWishedItemsToWishlistItems < ActiveRecord::Migration[8.1]
  # WishedItem becomes WishlistItem (docs/plans/5.4-store-api-naming-standardization.md).
  # All three indexes carry the default name Rails derives from the table, so
  # they are renamed along with it and none need moving by hand.
  def change
    rename_table :spree_wished_items, :spree_wishlist_items
  end
end
