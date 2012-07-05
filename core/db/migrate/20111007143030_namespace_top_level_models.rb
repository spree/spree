class NamespaceTopLevelModels < ActiveRecord::Migration
  def change
    rename_table :activators,              :spree_activators
    rename_table :addresses,               :spree_addresses
    rename_table :adjustments,             :spree_adjustments
    rename_table :configurations,          :spree_configurations
    rename_table :assets,                  :spree_assets
    rename_table :calculators,             :spree_calculators
    rename_table :countries,               :spree_countries
    rename_table :creditcards,             :spree_creditcards
    rename_table :gateways,                :spree_gateways
    rename_table :inventory_units,         :spree_inventory_units
    rename_table :line_items,              :spree_line_items
    rename_table :log_entries,             :spree_log_entries
    rename_table :mail_methods,            :spree_mail_methods
    rename_table :option_types,            :spree_option_types
    rename_table :option_values,           :spree_option_values
    rename_table :option_types_prototypes, :spree_option_types_prototypes
    rename_table :option_values_variants,  :spree_option_values_variants
    rename_table :orders,                  :spree_orders
    rename_table :payments,                :spree_payments
    rename_table :payment_methods,         :spree_payment_methods
    rename_table :preferences,             :spree_preferences
    rename_table :products,                :spree_products
    rename_table :product_option_types,    :spree_product_option_types
    rename_table :product_properties,      :spree_product_properties
    rename_table :products_taxons,         :spree_products_taxons
    rename_table :properties,              :spree_properties
    rename_table :prototypes,              :spree_prototypes
    rename_table :properties_prototypes,   :spree_properties_prototypes
    rename_table :return_authorizations,   :spree_return_authorizations
    rename_table :roles,                   :spree_roles
    rename_table :roles_users,             :spree_roles_users
    rename_table :shipments,               :spree_shipments
    rename_table :shipping_categories,     :spree_shipping_categories
    rename_table :shipping_methods,        :spree_shipping_methods
    rename_table :states,                  :spree_states
    rename_table :state_events,            :spree_state_events
    rename_table :tax_categories,          :spree_tax_categories
    rename_table :tax_rates,               :spree_tax_rates
    rename_table :taxons,                  :spree_taxons
    rename_table :taxonomies,              :spree_taxonomies
    rename_table :trackers,                :spree_trackers
    unless defined?(User) || table_exists?(:spree_users)
      rename_table :users,                   :spree_users
    end
    rename_table :variants,                :spree_variants
    rename_table :zones,                   :spree_zones
    rename_table :zone_members,            :spree_zone_members

    rename_index :spree_configurations, 'index_configurations_on_name_and_type', 'index_spree_configurations_on_name_and_type'
    rename_index :spree_line_items, 'index_line_items_on_order_id', 'index_spree_line_items_on_order_id'
    rename_index :spree_line_items, 'index_line_items_on_variant_id', 'index_spree_line_items_on_variant_id'
    rename_index :spree_option_values_variants, 'index_option_values_variants_on_variant_id', 'index_spree_option_values_variants_on_variant_id'
    rename_index :spree_orders, 'index_orders_on_number', 'index_spree_orders_on_number'
    rename_index :spree_preferences, 'index_preferences_on_owner_and_attribute_and_preference', 'index_spree_preferences_on_owner_and_attribute_and_preference'
    rename_index :spree_products, 'index_products_on_available_on', 'index_spree_products_on_available_on'
    rename_index :spree_products, 'index_products_on_deleted_at', 'index_spree_products_on_deleted_at'
    rename_index :spree_products, 'index_products_on_name', 'index_spree_products_on_name'
    rename_index :spree_products, 'index_products_on_permalink', 'index_spree_products_on_permalink'
    rename_index :spree_products_taxons, 'index_products_taxons_on_product_id', 'index_spree_products_taxons_on_product_id'
    rename_index :spree_products_taxons, 'index_products_taxons_on_taxon_id', 'index_spree_products_taxons_on_taxon_id'
    rename_index :spree_roles_users, 'index_roles_users_on_role_id', 'index_spree_roles_users_on_role_id'
    rename_index :spree_roles_users, 'index_roles_users_on_user_id', 'index_spree_roles_users_on_user_id'
    rename_index :spree_variants, 'index_variants_on_product_id', 'index_spree_variants_on_product_id'
  end
end
