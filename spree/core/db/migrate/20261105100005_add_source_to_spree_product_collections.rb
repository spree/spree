# `manual` for hand-picked products, `rule` for ones the collection's rules
# matched. Nullable until spree:collections:backfill_membership_sources has
# had a release to run; NOT NULL follows in 6.2.
class AddSourceToSpreeProductCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_product_collections, :source, :string
  end
end
