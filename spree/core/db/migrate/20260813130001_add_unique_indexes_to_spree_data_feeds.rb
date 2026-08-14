class AddUniqueIndexesToSpreeDataFeeds < ActiveRecord::Migration[8.1]
  # Backs the model's per-store name/slug uniqueness with real constraints —
  # both validations were index-less (race-unsafe) before. Existing data
  # cannot violate them: names were validated globally unique (a strict
  # superset of per-store), and slugs were already validated per store.
  def change
    add_index :spree_data_feeds, [:store_id, :name], unique: true
    add_index :spree_data_feeds, [:store_id, :slug], unique: true
  end
end
