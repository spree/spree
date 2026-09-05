class AddOpenToSellersToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    # Closed by default: a marketplace opens the products it wants sellers
    # competing on, and every existing product predates the decision
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 2).
    add_column :spree_products, :open_to_sellers, :boolean, default: false, null: false

    # The seller's catalog search filters on this beside the store and the
    # status, and nothing else reads it.
    add_index :spree_products, [:store_id, :open_to_sellers]
  end
end
