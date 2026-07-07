class AddStoreIdToSpreeProducts < ActiveRecord::Migration[7.2]
  # NOTE: After running this migration, existing products will have
  # +store_id IS NULL+ and be invisible to +Product.for_store+. Operators
  # upgrading from 5.4 MUST run the backfill task immediately afterwards:
  #
  #   bundle exec rake spree:upgrade:populate_publications
  #
  # The backfill is also chained from +spree:channels:upgrade+ so the full
  # 5.4 → 5.5 channel/publication upgrade is one command.
  def change
    add_reference :spree_products, :store, null: true, if_not_exists: true
    add_column :spree_products, :units_sold_count, :integer, default: 0, null: false, if_not_exists: true
    add_column :spree_products, :revenue, :decimal, precision: 16, scale: 4, default: 0, null: false, if_not_exists: true
    add_index :spree_products, %i[store_id units_sold_count], if_not_exists: true
  end
end
