class AddDefaultVariantIdToSpreeProducts < ActiveRecord::Migration[7.2]
  # Additive: the column is nullable and stays unused until the model cuts over
  # to the FK. Run +bundle exec rake spree:remove_master_variant+ afterwards to
  # backfill it.
  def change
    add_column :spree_products, :default_variant_id, :bigint
    add_index :spree_products, :default_variant_id
  end
end
