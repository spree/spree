class AddMissingIndexes < ActiveRecord::Migration
  def change
    # Below, add a composite index on [:adjustable_type, :adjustable_id]
    remove_index :spree_adjustments, name: "index_adjustments_on_order_id", column: :order_id

    # Below, add a composite index on [:viewable_type, :viewable_id]
    remove_index :spree_assets, name: "index_assets_on_viewable_id", column: :viewable_id

    # There doesn't seem to be any reason for this index
    remove_index :spree_assets, name: "index_assets_on_viewable_type_and_type", column: [:viewable_type, :type]

    add_index :spree_adjustments, :order_id
    add_index :spree_adjustments, [:adjustable_type, :adjustable_id]
    add_index :spree_assets, [:viewable_type, :viewable_id]
    add_index :spree_inventory_units, :return_authorization_id
    add_index :spree_line_items, :tax_category_id
    add_index :spree_log_entries, [:source_type, :source_id]
    add_index :spree_option_types_prototypes, :option_type_id
    add_index :spree_option_types_prototypes, :prototype_id
    add_index :spree_option_values_variants, :option_value_id
    add_index :spree_orders, :approver_id
    add_index :spree_orders_promotions, :order_id
    add_index :spree_orders_promotions, :promotion_id
    add_index :spree_payments, [:source_id, :source_type]
    add_index :spree_product_option_types, :option_type_id
    add_index :spree_product_option_types, :product_id
    add_index :spree_products_taxons, [:product_id, :position]
    add_index :spree_promotion_action_line_items, :promotion_action_id
    add_index :spree_promotion_action_line_items, :variant_id
    add_index :spree_promotion_rules, :promotion_id
    add_index :spree_promotion_rules, [:id, :type]
    add_index :spree_properties_prototypes, :property_id
    add_index :spree_properties_prototypes, :prototype_id
    add_index :spree_return_authorizations, :order_id
    add_index :spree_shipping_method_categories, :shipping_category_id
    add_index :spree_shipping_methods_zones, :shipping_method_id
    add_index :spree_shipping_methods_zones, :zone_id
    add_index :spree_shipping_rates, :shipment_id
    add_index :spree_shipping_rates, :shipping_method_id
    add_index :spree_states, [:country_id, :name]
    add_index :spree_stock_items, :variant_id
    add_index :spree_tax_rates, :tax_category_id
    add_index :spree_tax_rates, :zone_id
    add_index :spree_zone_members, :zone_id
    add_index :spree_zone_members, [:zoneable_id, :zoneable_type]
  end
end
