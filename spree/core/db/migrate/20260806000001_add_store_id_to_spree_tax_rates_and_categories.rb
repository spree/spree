class AddStoreIdToSpreeTaxRatesAndCategories < ActiveRecord::Migration[8.1]
  def change
    # Tax rates and tax categories are the internal tax provider's entire
    # configuration, so they belong to a store like every other commerce
    # setting. Kept null: true here; existing rows are backfilled by
    # `spree:backfill_tax_store_ids` and presence is enforced on the model.
    # The NOT NULL constraints land in 6.1.
    add_reference :spree_tax_rates, :store, null: true
    add_reference :spree_tax_categories, :store, null: true

    # Category names are unique per store. Legacy rows carry a NULL store_id
    # until the backfill runs, and NULLs never collide in a unique index, so
    # this constraint starts enforcing only once rows are bound to a store.
    add_index :spree_tax_categories, [:store_id, :name], unique: true, where: 'deleted_at IS NULL'
  end
end
