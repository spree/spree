class AddIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_assets, :position
    add_index :spree_option_types, :name
    add_index :spree_option_values, :name
    add_index :spree_prices, :variant_id
    add_index :spree_properties, :name
    add_index :spree_roles, :name
    add_index :spree_shipping_categories, :name
    add_index :spree_taxons, :lft
    add_index :spree_taxons, :rgt
    add_index :spree_taxons, :name
  end
end
