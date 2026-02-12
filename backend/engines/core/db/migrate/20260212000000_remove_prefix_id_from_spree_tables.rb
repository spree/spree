# frozen_string_literal: true

class RemovePrefixIdFromSpreeTables < ActiveRecord::Migration[7.2]
  def change
    tables = %i[
      spree_addresses
      spree_adjustments
      spree_api_keys
      spree_assets
      spree_calculators
      spree_coupon_codes
      spree_credit_cards
      spree_custom_domains
      spree_customer_groups
      spree_customer_returns
      spree_data_feeds
      spree_digital_links
      spree_digitals
      spree_exports
      spree_gateway_customers
      spree_gift_card_batches
      spree_gift_cards
      spree_import_mappings
      spree_import_rows
      spree_imports
      spree_integrations
      spree_inventory_units
      spree_invitations
      spree_line_items
      spree_log_entries
      spree_metafield_definitions
      spree_metafields
      spree_newsletter_subscribers
      spree_option_types
      spree_option_values
      spree_orders
      spree_payment_capture_events
      spree_payment_methods
      spree_payment_sources
      spree_payments
      spree_policies
      spree_post_categories
      spree_posts
      spree_price_lists
      spree_price_rules
      spree_prices
      spree_products
      spree_products_stores
      spree_promotion_actions
      spree_promotion_categories
      spree_promotion_rules
      spree_promotions
      spree_prototypes
      spree_refund_reasons
      spree_refunds
      spree_reimbursement_credits
      spree_reimbursement_types
      spree_reimbursements
      spree_reports
      spree_return_authorization_reasons
      spree_return_authorizations
      spree_return_items
      spree_roles
      spree_shipments
      spree_shipping_categories
      spree_shipping_method_categories
      spree_shipping_methods
      spree_shipping_rates
      spree_state_changes
      spree_stock_items
      spree_stock_locations
      spree_stock_movements
      spree_stock_transfers
      spree_store_credit_categories
      spree_store_credit_events
      spree_store_credit_types
      spree_store_credits
      spree_stores
      spree_tax_categories
      spree_tax_rates
      spree_taxon_rules
      spree_taxons
      spree_taxonomies
      spree_user_identities
      spree_variants
      spree_webhook_deliveries
      spree_webhook_endpoints
      spree_wished_items
      spree_wishlists
      spree_zones
    ]

    tables.each do |table|
      next unless table_exists?(table)

      remove_index table, :prefix_id, if_exists: true
      remove_column table, :prefix_id, :string, if_exists: true
    end

    [Spree.user_class, Spree.admin_user_class].compact.each do |user_class|
      next unless table_exists?(user_class.table_name)

      remove_index user_class.table_name, :prefix_id, if_exists: true
      remove_column user_class.table_name, :prefix_id, :string, if_exists: true
    end
  end
end
