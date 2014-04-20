class AddPreferenceStoreToEverything < ActiveRecord::Migration
  def change
    add_column :spree_calculators, :preferences, :text
    add_column :spree_gateways, :preferences, :text
    add_column :spree_payment_methods, :preferences, :text
    add_column :spree_promotion_rules, :preferences, :text
    add_column :spree_option_types, :preferences, :text
    add_column :spree_option_values, :preferences, :text
    add_column :spree_properties, :preferences, :text
    add_column :spree_prototypes, :preferences, :text
    add_column :spree_shipping_categories, :preferences, :text
    add_column :spree_shipping_methods, :preferences, :text
    add_column :spree_shipping_method_categories, :preferences, :text
    add_column :spree_stock_locations, :preferences, :text
    add_column :spree_tax_categories, :preferences, :text
    add_column :spree_taxons, :preferences, :text
    add_column :spree_taxonomies, :preferences, :text
    add_column :spree_variants, :preferences, :text    
  end
end
