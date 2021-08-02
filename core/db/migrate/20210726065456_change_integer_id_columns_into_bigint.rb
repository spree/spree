class ChangeIntegerIdColumnsIntoBigint < ActiveRecord::Migration[5.2]
  def change
    change_table(:active_storage_attachments) do |t|
      t.change :record_id, :bigint
      t.change :blob_id, :bigint
    end

    change_column :friendly_id_slugs, :sluggable_id, :bigint

    change_table(:spree_addresses) do |t|
      t.change :state_id, :bigint
      t.change :country_id, :bigint
      t.change :user_id, :bigint
    end

    change_table(:spree_adjustments) do |t|
      t.change :source_id, :bigint
      t.change :adjustable_id, :bigint
      t.change :order_id, :bigint
    end

    change_column :spree_assets, :viewable_id, :bigint

    change_column :spree_calculators, :calculable_id, :bigint

    change_table(:spree_credit_cards) do |t|
      t.change :address_id, :bigint
      t.change :user_id, :bigint
      t.change :payment_method_id, :bigint
    end

    change_column :spree_customer_returns, :stock_location_id, :bigint

    change_table(:spree_inventory_units) do |t|
      t.change :variant_id, :bigint
      t.change :order_id, :bigint
      t.change :shipment_id, :bigint
      t.change :line_item_id, :bigint
      t.change :original_return_item_id, :bigint
    end

    change_table(:spree_line_items) do |t|
      t.change :variant_id, :bigint
      t.change :order_id, :bigint
      t.change :tax_category_id, :bigint
    end

    change_column :spree_log_entries, :source_id, :bigint

    change_table(:spree_menu_items) do |t|
      t.change :linked_resource_id, :bigint
      t.change :parent_id, :bigint
      t.change :lft, :bigint
      t.change :rgt, :bigint
      t.change :menu_id, :bigint
    end

    change_column :spree_menus, :store_id, :bigint

    change_table(:spree_option_type_prototypes) do |t|
      t.change :prototype_id, :bigint
      t.change :option_type_id, :bigint
    end

    change_table(:spree_option_value_variants) do |t|
      t.change :variant_id, :bigint
      t.change :option_value_id, :bigint
    end

    change_column :spree_option_values, :option_type_id, :bigint

    change_table(:spree_order_promotions) do |t|
      t.change :order_id, :bigint
      t.change :promotion_id, :bigint
    end

    change_table(:spree_orders) do |t|
      t.change :user_id, :bigint
      t.change :bill_address_id, :bigint
      t.change :ship_address_id, :bigint
      t.change :created_by_id, :bigint
      t.change :approver_id, :bigint
      t.change :canceler_id, :bigint
      t.change :store_id, :bigint
    end

    change_column :spree_payment_capture_events, :payment_id, :bigint

    change_table(:spree_payment_methods_stores) do |t|
      t.change :payment_method_id, :bigint
      t.change :store_id, :bigint
    end

    change_table(:spree_payments) do |t|
      t.change :order_id, :bigint
      t.change :source_id, :bigint
      t.change :payment_method_id, :bigint
    end

    change_column :spree_prices, :variant_id, :bigint

    change_table(:spree_product_option_types) do |t|
      t.change :product_id, :bigint
      t.change :option_type_id, :bigint
    end

    change_table(:spree_product_promotion_rules) do |t|
      t.change :product_id, :bigint
      t.change :promotion_rule_id, :bigint
    end

    change_table(:spree_product_properties) do |t|
      t.change :product_id, :bigint
      t.change :property_id, :bigint
    end

    change_table(:spree_products) do |t|
      t.change :tax_category_id, :bigint
      t.change :shipping_category_id, :bigint
    end

    change_table(:spree_products_stores) do |t|
      t.change :product_id, :bigint
      t.change :store_id, :bigint
    end

    change_table(:spree_products_taxons) do |t|
      t.change :product_id, :bigint
      t.change :taxon_id, :bigint
    end

    change_table(:spree_promotion_action_line_items) do |t|
      t.change :promotion_action_id, :bigint
      t.change :variant_id, :bigint
    end

    change_column :spree_promotion_actions, :promotion_id, :bigint

    change_table(:spree_promotion_rule_taxons) do |t|
      t.change :taxon_id, :bigint
      t.change :promotion_rule_id, :bigint
    end

    change_table(:spree_promotion_rule_users) do |t|
      t.change :user_id, :bigint
      t.change :promotion_rule_id, :bigint
    end

    change_table(:spree_promotion_rules) do |t|
      t.change :promotion_id, :bigint
      t.change :user_id, :bigint
      t.change :product_group_id, :bigint
    end

    change_column :spree_promotions, :promotion_category_id, :bigint

    change_table(:spree_promotions_stores) do |t|
      t.change :promotion_id, :bigint
      t.change :store_id, :bigint
    end

    change_table(:spree_property_prototypes) do |t|
      t.change :prototype_id, :bigint
      t.change :property_id, :bigint
    end

    change_table(:spree_prototype_taxons) do |t|
      t.change :taxon_id, :bigint
      t.change :prototype_id, :bigint
    end

    change_table(:spree_refunds) do |t|
      t.change :payment_id, :bigint
      t.change :refund_reason_id, :bigint
      t.change :reimbursement_id, :bigint
    end

    change_table(:spree_reimbursement_credits) do |t|
      t.change :reimbursement_id, :bigint
      t.change :creditable_id, :bigint
    end

    change_table(:spree_reimbursements) do |t|
      t.change :customer_return_id, :bigint
      t.change :order_id, :bigint
    end

    change_table(:spree_return_authorizations) do |t|
      t.change :order_id, :bigint
      t.change :stock_location_id, :bigint
      t.change :return_authorization_reason_id, :bigint
    end

    change_table(:spree_return_items) do |t|
      t.change :return_authorization_id, :bigint
      t.change :inventory_unit_id, :bigint
      t.change :exchange_variant_id, :bigint
      t.change :customer_return_id, :bigint
      t.change :reimbursement_id, :bigint
      t.change :preferred_reimbursement_type_id, :bigint
      t.change :override_reimbursement_type_id, :bigint
    end

    change_table(:spree_role_users) do |t|
      t.change :role_id, :bigint
      t.change :user_id, :bigint
    end

    change_table(:spree_shipments) do |t|
      t.change :order_id, :bigint
      t.change :address_id, :bigint
      t.change :stock_location_id, :bigint
    end

    change_table(:spree_shipping_method_categories) do |t|
      t.change :shipping_method_id, :bigint
      t.change :shipping_category_id, :bigint
    end

    change_table(:spree_shipping_method_zones) do |t|
      t.change :shipping_method_id, :bigint
      t.change :zone_id, :bigint
    end

    change_column :spree_shipping_methods, :tax_category_id, :bigint

    change_table(:spree_shipping_rates) do |t|
      t.change :shipment_id, :bigint
      t.change :shipping_method_id, :bigint
      t.change :tax_rate_id, :bigint
    end

    change_table(:spree_state_changes) do |t|
      t.change :stateful_id, :bigint
      t.change :user_id, :bigint
    end

    change_column :spree_states, :country_id, :bigint

    change_table(:spree_stock_items) do |t|
      t.change :stock_location_id, :bigint
      t.change :variant_id, :bigint
    end

    change_table(:spree_stock_locations) do |t|
      t.change :state_id, :bigint
      t.change :country_id, :bigint
    end

    change_table(:spree_stock_movements) do |t|
      t.change :stock_item_id, :bigint
      t.change :originator_id, :bigint
    end

    change_table(:spree_stock_transfers) do |t|
      t.change :source_location_id, :bigint
      t.change :destination_location_id, :bigint
    end

    change_table(:spree_store_credit_events) do |t|
      t.change :store_credit_id, :bigint
      t.change :originator_id, :bigint
    end

    change_table(:spree_store_credits) do |t|
      t.change :user_id, :bigint
      t.change :category_id, :bigint
      t.change :created_by_id, :bigint
      t.change :originator_id, :bigint
      t.change :type_id, :bigint
    end

    change_table(:spree_stores) do |t|
      t.change :default_country_id, :bigint
      t.change :checkout_zone_id, :bigint
    end

    change_table(:spree_tax_rates) do |t|
      t.change :zone_id, :bigint
      t.change :tax_category_id, :bigint
    end

    change_table(:spree_taxons) do |t|
      t.change :parent_id, :bigint
      t.change :taxonomy_id, :bigint
      t.change :lft, :bigint
      t.change :rgt, :bigint
    end

    change_table(:spree_users) do |t|
      t.change :ship_address_id, :bigint
      t.change :bill_address_id, :bigint
    end

    change_table(:spree_variants) do |t|
      t.change :product_id, :bigint
      t.change :tax_category_id, :bigint
    end

    change_table(:spree_zone_members) do |t|
      t.change :zoneable_id, :bigint
      t.change :zone_id, :bigint
    end
  end
end
