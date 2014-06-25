class AddManyMissingIndexes < ActiveRecord::Migration
  def change
    add_index :spree_adjustments, [:adjustable_id, :adjustable_type]
    add_index :spree_adjustments, :eligible
    add_index :spree_adjustments, :order_id
    add_index :spree_promotions, :code
    add_index :spree_promotions, :expires_at
    add_index :spree_states, :country_id
    add_index :spree_stock_items, :deleted_at
    add_index :spree_option_types, :position
    add_index :spree_option_values, :position
    add_index :spree_product_option_types, :option_type_id
    add_index :spree_product_option_types, :product_id
    add_index :spree_products_taxons, :position
    add_index :spree_promotions, :starts_at
    add_index :spree_stores, :url
  end
end
