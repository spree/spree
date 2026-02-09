# This migration comes from spree (originally 20260119120000)
class AddCounterCachesToSpreeProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_products, :variant_count, :integer, default: 0, null: false, if_not_exists: true
    add_column :spree_products, :classification_count, :integer, default: 0, null: false, if_not_exists: true

    add_index :spree_products, :variant_count, if_not_exists: true
    add_index :spree_products, :classification_count, if_not_exists: true
  end
end
