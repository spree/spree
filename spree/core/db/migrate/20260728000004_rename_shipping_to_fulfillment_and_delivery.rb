class RenameShippingToFulfillmentAndDelivery < ActiveRecord::Migration[7.2]
  def change
    # Old-name indexes are dropped up front and re-added under stable names
    # after the renames — several carry non-generated names (e.g.
    # index_inventory_units_on_order_id) that Rails' automatic index renaming
    # would leave stale, and the generated replacements stay well under
    # PostgreSQL's 63-char identifier limit only when added fresh.
    remove_index :spree_shipments, column: :address_id, name: 'index_spree_shipments_on_address_id', if_exists: true
    remove_index :spree_shipments, column: :number, unique: true, name: 'index_spree_shipments_on_number', if_exists: true
    remove_index :spree_shipments, column: :order_id, name: 'index_spree_shipments_on_order_id', if_exists: true
    remove_index :spree_shipments, column: :stock_location_id, name: 'index_spree_shipments_on_stock_location_id', if_exists: true

    remove_index :spree_inventory_units, column: :line_item_id, name: 'index_spree_inventory_units_on_line_item_id', if_exists: true
    remove_index :spree_inventory_units, column: :order_id, name: 'index_inventory_units_on_order_id', if_exists: true
    remove_index :spree_inventory_units, column: :original_return_item_id, name: 'index_spree_inventory_units_on_original_return_item_id', if_exists: true
    remove_index :spree_inventory_units, column: :shipment_id, name: 'index_inventory_units_on_shipment_id', if_exists: true
    remove_index :spree_inventory_units, column: :variant_id, name: 'index_inventory_units_on_variant_id', if_exists: true

    remove_index :spree_shipping_rates, column: :selected, name: 'index_spree_shipping_rates_on_selected', if_exists: true
    remove_index :spree_shipping_rates, column: [:shipment_id, :shipping_method_id], unique: true, name: 'spree_shipping_rates_join_index', if_exists: true
    remove_index :spree_shipping_rates, column: :shipment_id, name: 'index_spree_shipping_rates_on_shipment_id', if_exists: true
    remove_index :spree_shipping_rates, column: :shipping_method_id, name: 'index_spree_shipping_rates_on_shipping_method_id', if_exists: true
    remove_index :spree_shipping_rates, column: :tax_rate_id, name: 'index_spree_shipping_rates_on_tax_rate_id', if_exists: true

    remove_index :spree_shipping_methods, column: :deleted_at, name: 'index_spree_shipping_methods_on_deleted_at', if_exists: true
    remove_index :spree_shipping_methods, column: :tax_category_id, name: 'index_spree_shipping_methods_on_tax_category_id', if_exists: true

    remove_index :spree_shipping_method_zones, column: :shipping_method_id, name: 'index_spree_shipping_method_zones_on_shipping_method_id', if_exists: true
    remove_index :spree_shipping_method_zones, column: :zone_id, name: 'index_spree_shipping_method_zones_on_zone_id', if_exists: true

    remove_index :spree_return_items, column: :inventory_unit_id, name: 'index_spree_return_items_on_inventory_unit_id', if_exists: true

    rename_table :spree_shipments, :spree_fulfillments
    rename_table :spree_shipping_methods, :spree_delivery_methods
    rename_table :spree_shipping_rates, :spree_delivery_rates
    rename_table :spree_inventory_units, :spree_fulfillment_items
    rename_table :spree_shipping_method_zones, :spree_delivery_method_zones

    rename_column :spree_fulfillments, :state, :status
    rename_column :spree_fulfillments, :shipped_at, :fulfilled_at
    rename_column :spree_fulfillment_items, :state, :status
    rename_column :spree_fulfillment_items, :shipment_id, :fulfillment_id
    rename_column :spree_delivery_rates, :shipment_id, :fulfillment_id
    rename_column :spree_delivery_rates, :shipping_method_id, :delivery_method_id
    rename_column :spree_delivery_method_zones, :shipping_method_id, :delivery_method_id
    rename_column :spree_delivery_method_zones, :zone_id, :delivery_zone_id
    rename_column :spree_return_items, :inventory_unit_id, :fulfillment_item_id
    rename_column :spree_orders, :shipment_state, :fulfillment_status
    rename_column :spree_orders, :shipment_total, :delivery_total

    # Authoritative from 6.0; display_on stays readable until the 6.1 drop.
    # Existing rows get their real value from the spree:migrate_shipping_to_delivery
    # data task, which runs after this migration.
    add_column :spree_delivery_methods, :storefront_visible, :boolean, null: false, default: true

    add_index :spree_fulfillments, :address_id
    add_index :spree_fulfillments, :number, unique: true
    add_index :spree_fulfillments, :order_id
    add_index :spree_fulfillments, :stock_location_id

    add_index :spree_fulfillment_items, :line_item_id
    add_index :spree_fulfillment_items, :order_id
    add_index :spree_fulfillment_items, :original_return_item_id
    add_index :spree_fulfillment_items, :fulfillment_id
    add_index :spree_fulfillment_items, :variant_id

    add_index :spree_delivery_rates, :selected
    add_index :spree_delivery_rates, [:fulfillment_id, :delivery_method_id], unique: true, name: 'spree_delivery_rates_join_index'
    add_index :spree_delivery_rates, :fulfillment_id
    add_index :spree_delivery_rates, :delivery_method_id
    add_index :spree_delivery_rates, :tax_rate_id

    add_index :spree_delivery_methods, :deleted_at
    add_index :spree_delivery_methods, :tax_category_id

    add_index :spree_delivery_method_zones, :delivery_method_id
    add_index :spree_delivery_method_zones, :delivery_zone_id

    add_index :spree_return_items, :fulfillment_item_id

    add_index :spree_orders, :fulfillment_status
  end
end
