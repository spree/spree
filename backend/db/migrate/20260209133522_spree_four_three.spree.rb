# This migration comes from spree (originally 20210914000000)
class SpreeFourThree < ActiveRecord::Migration[5.2]
  def up
    # This migration is just a compressed version of all the previous
    # migrations for spree_core. Do not run it if one of the core tables
    # already exists. Assume the best.
    return if data_source_exists?(:spree_addresses)

    create_table "friendly_id_slugs", force: :cascade do |t|
      t.string "slug", null: false
      t.bigint "sluggable_id", null: false
      t.string "sluggable_type", limit: 50
      t.string "scope"
      t.datetime "created_at"
      t.datetime "deleted_at"
      t.index ["deleted_at"], name: "index_friendly_id_slugs_on_deleted_at"
      t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
      t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
      t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
      t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
    end

    create_table "spree_addresses", force: :cascade do |t|
      t.string "firstname"
      t.string "lastname"
      t.string "address1"
      t.string "address2"
      t.string "city"
      t.string "zipcode"
      t.string "phone"
      t.string "state_name"
      t.string "alternative_phone"
      t.string "company"
      t.bigint "state_id"
      t.bigint "country_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "user_id"
      t.datetime "deleted_at"
      t.string "label"
      t.index ["country_id"], name: "index_spree_addresses_on_country_id"
      t.index ["deleted_at"], name: "index_spree_addresses_on_deleted_at"
      t.index ["firstname"], name: "index_addresses_on_firstname"
      t.index ["lastname"], name: "index_addresses_on_lastname"
      t.index ["state_id"], name: "index_spree_addresses_on_state_id"
      t.index ["user_id"], name: "index_spree_addresses_on_user_id"
    end

    create_table "spree_adjustments", force: :cascade do |t|
      t.string "source_type"
      t.bigint "source_id"
      t.string "adjustable_type"
      t.bigint "adjustable_id"
      t.decimal "amount", precision: 10, scale: 2
      t.string "label"
      t.boolean "mandatory"
      t.boolean "eligible", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "state"
      t.bigint "order_id", null: false
      t.boolean "included", default: false
      t.index ["adjustable_id", "adjustable_type"], name: "index_spree_adjustments_on_adjustable_id_and_adjustable_type"
      t.index ["eligible"], name: "index_spree_adjustments_on_eligible"
      t.index ["order_id"], name: "index_spree_adjustments_on_order_id"
      t.index ["source_id", "source_type"], name: "index_spree_adjustments_on_source_id_and_source_type"
    end

    create_table "spree_assets", force: :cascade do |t|
      t.string "viewable_type"
      t.bigint "viewable_id"
      t.integer "attachment_width"
      t.integer "attachment_height"
      t.integer "attachment_file_size"
      t.integer "position"
      t.string "attachment_content_type"
      t.string "attachment_file_name"
      t.string "type", limit: 75
      t.datetime "attachment_updated_at"
      t.text "alt"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["position"], name: "index_spree_assets_on_position"
      t.index ["viewable_id"], name: "index_assets_on_viewable_id"
      t.index ["viewable_type", "type"], name: "index_assets_on_viewable_type_and_type"
    end

    create_table "spree_calculators", force: :cascade do |t|
      t.string "type"
      t.string "calculable_type"
      t.bigint "calculable_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.text "preferences"
      t.datetime "deleted_at"
      t.index ["calculable_id", "calculable_type"], name: "index_spree_calculators_on_calculable_id_and_calculable_type"
      t.index ["deleted_at"], name: "index_spree_calculators_on_deleted_at"
      t.index ["id", "type"], name: "index_spree_calculators_on_id_and_type"
    end

    create_table "spree_countries", force: :cascade do |t|
      t.string "iso_name"
      t.string "iso", null: false
      t.string "iso3", null: false
      t.string "name"
      t.integer "numcode"
      t.boolean "states_required", default: false
      t.datetime "updated_at"
      t.boolean "zipcode_required", default: true
      t.datetime "created_at"
      t.index ["iso_name"], name: "index_spree_countries_on_iso_name", unique: true
      t.index ["name"], name: "index_spree_countries_on_name", unique: true
      t.index ["iso"], name: "index_spree_countries_on_iso", unique: true
      t.index ["iso3"], name: "index_spree_countries_on_iso3", unique: true
    end

    create_table "spree_credit_cards", force: :cascade do |t|
      t.string "month"
      t.string "year"
      t.string "cc_type"
      t.string "last_digits"
      t.bigint "address_id"
      t.string "gateway_customer_profile_id"
      t.string "gateway_payment_profile_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "name"
      t.bigint "user_id"
      t.bigint "payment_method_id"
      t.boolean "default", default: false, null: false
      t.datetime "deleted_at"
      t.index ["address_id"], name: "index_spree_credit_cards_on_address_id"
      t.index ["deleted_at"], name: "index_spree_credit_cards_on_deleted_at"
      t.index ["payment_method_id"], name: "index_spree_credit_cards_on_payment_method_id"
      t.index ["user_id"], name: "index_spree_credit_cards_on_user_id"
    end

    create_table "spree_customer_returns", force: :cascade do |t|
      t.string "number"
      t.bigint "stock_location_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "store_id"
      t.index ["number"], name: "index_spree_customer_returns_on_number", unique: true
      t.index ["stock_location_id"], name: "index_spree_customer_returns_on_stock_location_id"
      t.index ["store_id"], name: "index_spree_customer_returns_on_store_id"
    end

    create_table "spree_gateways", force: :cascade do |t|
      t.string "type"
      t.string "name"
      t.text "description"
      t.boolean "active", default: true
      t.string "environment", default: "development"
      t.string "server", default: "test"
      t.boolean "test_mode", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.text "preferences"
      t.index ["active"], name: "index_spree_gateways_on_active"
      t.index ["test_mode"], name: "index_spree_gateways_on_test_mode"
    end

    create_table "spree_inventory_units", force: :cascade do |t|
      t.string "state"
      t.bigint "variant_id"
      t.bigint "order_id"
      t.bigint "shipment_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "pending", default: true
      t.bigint "line_item_id"
      t.integer "quantity", default: 1
      t.bigint "original_return_item_id"
      t.index ["line_item_id"], name: "index_spree_inventory_units_on_line_item_id"
      t.index ["order_id"], name: "index_inventory_units_on_order_id"
      t.index ["original_return_item_id"], name: "index_spree_inventory_units_on_original_return_item_id"
      t.index ["shipment_id"], name: "index_inventory_units_on_shipment_id"
      t.index ["variant_id"], name: "index_inventory_units_on_variant_id"
    end

    create_table "spree_line_items", force: :cascade do |t|
      t.bigint "variant_id"
      t.bigint "order_id"
      t.integer "quantity", null: false
      t.decimal "price", precision: 10, scale: 2, null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "currency"
      t.decimal "cost_price", precision: 10, scale: 2
      t.bigint "tax_category_id"
      t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
      t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.index ["order_id"], name: "index_spree_line_items_on_order_id"
      t.index ["tax_category_id"], name: "index_spree_line_items_on_tax_category_id"
      t.index ["variant_id"], name: "index_spree_line_items_on_variant_id"
    end

    create_table "spree_log_entries", force: :cascade do |t|
      t.string "source_type"
      t.bigint "source_id"
      t.text "details"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["source_id", "source_type"], name: "index_spree_log_entries_on_source_id_and_source_type"
    end

    create_table "spree_option_type_prototypes", force: :cascade do |t|
      t.bigint "prototype_id"
      t.bigint "option_type_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["option_type_id"], name: "index_spree_option_type_prototypes_on_option_type_id"
      t.index ["prototype_id", "option_type_id"], name: "spree_option_type_prototypes_prototype_id_option_type_id", unique: true
      t.index ["prototype_id"], name: "index_spree_option_type_prototypes_on_prototype_id"
    end

    create_table "spree_option_types", force: :cascade do |t|
      t.string "name", limit: 100
      t.string "presentation", limit: 100
      t.integer "position", default: 0, null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "filterable", default: true, null: false
      t.index ["filterable"], name: "index_spree_option_types_on_filterable"
      t.index ["name"], name: "index_spree_option_types_on_name"
      t.index ["position"], name: "index_spree_option_types_on_position"
    end

    create_table "spree_option_value_variants", force: :cascade do |t|
      t.bigint "variant_id"
      t.bigint "option_value_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["option_value_id"], name: "index_spree_option_value_variants_on_option_value_id"
      t.index ["variant_id", "option_value_id"], name: "index_option_values_variants_on_variant_id_and_option_value_id", unique: true
      t.index ["variant_id"], name: "index_spree_option_value_variants_on_variant_id"
    end

    create_table "spree_option_values", force: :cascade do |t|
      t.integer "position"
      t.string "name"
      t.string "presentation"
      t.bigint "option_type_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["name"], name: "index_spree_option_values_on_name"
      t.index ["option_type_id"], name: "index_spree_option_values_on_option_type_id"
      t.index ["position"], name: "index_spree_option_values_on_position"
    end

    create_table "spree_order_promotions", force: :cascade do |t|
      t.bigint "order_id"
      t.bigint "promotion_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["order_id"], name: "index_spree_order_promotions_on_order_id"
      t.index ["promotion_id", "order_id"], name: "index_spree_order_promotions_on_promotion_id_and_order_id"
      t.index ["promotion_id"], name: "index_spree_order_promotions_on_promotion_id"
    end

    create_table "spree_orders", force: :cascade do |t|
      t.string "number", limit: 32
      t.decimal "item_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
      t.string "state"
      t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.bigint "user_id"
      t.datetime "completed_at"
      t.bigint "bill_address_id"
      t.bigint "ship_address_id"
      t.decimal "payment_total", precision: 10, scale: 2, default: "0.0"
      t.string "shipment_state"
      t.string "payment_state"
      t.string "email"
      t.text "special_instructions"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "currency"
      t.string "last_ip_address"
      t.bigint "created_by_id"
      t.decimal "shipment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
      t.string "channel", default: "spree"
      t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
      t.integer "item_count", default: 0
      t.bigint "approver_id"
      t.datetime "approved_at"
      t.boolean "confirmation_delivered", default: false
      t.boolean "considered_risky", default: false
      t.string "token"
      t.datetime "canceled_at"
      t.bigint "canceler_id"
      t.bigint "store_id"
      t.integer "state_lock_version", default: 0, null: false
      t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.boolean "store_owner_notification_delivered"
      t.index ["approver_id"], name: "index_spree_orders_on_approver_id"
      t.index ["bill_address_id"], name: "index_spree_orders_on_bill_address_id"
      t.index ["canceler_id"], name: "index_spree_orders_on_canceler_id"
      t.index ["completed_at"], name: "index_spree_orders_on_completed_at"
      t.index ["confirmation_delivered"], name: "index_spree_orders_on_confirmation_delivered"
      t.index ["considered_risky"], name: "index_spree_orders_on_considered_risky"
      t.index ["created_by_id"], name: "index_spree_orders_on_created_by_id"
      t.index ["number"], name: "index_spree_orders_on_number", unique: true
      t.index ["ship_address_id"], name: "index_spree_orders_on_ship_address_id"
      t.index ["store_id"], name: "index_spree_orders_on_store_id"
      t.index ["token"], name: "index_spree_orders_on_token"
      t.index ["user_id", "created_by_id"], name: "index_spree_orders_on_user_id_and_created_by_id"
    end

    create_table "spree_payment_capture_events", force: :cascade do |t|
      t.decimal "amount", precision: 10, scale: 2, default: "0.0"
      t.bigint "payment_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["payment_id"], name: "index_spree_payment_capture_events_on_payment_id"
    end

    create_table "spree_payment_methods", force: :cascade do |t|
      t.string "type"
      t.string "name"
      t.text "description"
      t.boolean "active", default: true
      t.datetime "deleted_at"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "display_on", default: "both"
      t.boolean "auto_capture"
      t.text "preferences"
      t.integer "position", default: 0
      t.index ["id", "type"], name: "index_spree_payment_methods_on_id_and_type"
    end

    create_table "spree_payment_methods_stores", id: false, force: :cascade do |t|
      t.bigint "payment_method_id"
      t.bigint "store_id"
      t.index ["payment_method_id", "store_id"], name: "payment_mentod_id_store_id_unique_index", unique: true
      t.index ["payment_method_id"], name: "index_spree_payment_methods_stores_on_payment_method_id"
      t.index ["store_id"], name: "index_spree_payment_methods_stores_on_store_id"
    end

    create_table "spree_payments", force: :cascade do |t|
      t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
      t.bigint "order_id"
      t.string "source_type"
      t.bigint "source_id"
      t.bigint "payment_method_id"
      t.string "state"
      t.string "response_code"
      t.string "avs_response"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "number"
      t.string "cvv_response_code"
      t.string "cvv_response_message"
      t.index ["number"], name: "index_spree_payments_on_number", unique: true
      t.index ["order_id"], name: "index_spree_payments_on_order_id"
      t.index ["payment_method_id"], name: "index_spree_payments_on_payment_method_id"
      t.index ["source_id", "source_type"], name: "index_spree_payments_on_source_id_and_source_type"
    end

    create_table "spree_preferences", force: :cascade do |t|
      t.text "value"
      t.string "key"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["key"], name: "index_spree_preferences_on_key", unique: true
    end

    create_table "spree_prices", force: :cascade do |t|
      t.bigint "variant_id", null: false
      t.decimal "amount", precision: 10, scale: 2
      t.string "currency"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.decimal "compare_at_amount", precision: 10, scale: 2
      t.index ["deleted_at"], name: "index_spree_prices_on_deleted_at"
      t.index ["variant_id", "currency"], name: "index_spree_prices_on_variant_id_and_currency"
      t.index ["variant_id"], name: "index_spree_prices_on_variant_id"
    end

    create_table "spree_product_option_types", force: :cascade do |t|
      t.integer "position"
      t.bigint "product_id"
      t.bigint "option_type_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["option_type_id"], name: "index_spree_product_option_types_on_option_type_id"
      t.index ["position"], name: "index_spree_product_option_types_on_position"
      t.index ["product_id"], name: "index_spree_product_option_types_on_product_id"
    end

    create_table "spree_product_promotion_rules", force: :cascade do |t|
      t.bigint "product_id"
      t.bigint "promotion_rule_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["product_id"], name: "index_products_promotion_rules_on_product_id"
      t.index ["promotion_rule_id", "product_id"], name: "index_products_promotion_rules_on_promotion_rule_and_product"
    end

    create_table "spree_product_properties", force: :cascade do |t|
      t.string "value"
      t.bigint "product_id"
      t.bigint "property_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.integer "position", default: 0
      t.boolean "show_property", default: true
      t.string "filter_param"
      t.index ["filter_param"], name: "index_spree_product_properties_on_filter_param"
      t.index ["position"], name: "index_spree_product_properties_on_position"
      t.index ["product_id"], name: "index_product_properties_on_product_id"
      t.index ["property_id", "product_id"], name: "index_spree_product_properties_on_property_id_and_product_id", unique: true
      t.index ["property_id"], name: "index_spree_product_properties_on_property_id"
    end

    create_table "spree_products", force: :cascade do |t|
      t.string "name", default: "", null: false
      t.text "description"
      t.datetime "available_on"
      t.datetime "deleted_at"
      t.string "slug"
      t.text "meta_description"
      t.string "meta_keywords"
      t.bigint "tax_category_id"
      t.bigint "shipping_category_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "promotionable", default: true
      t.string "meta_title"
      t.datetime "discontinue_on"
      t.index ["available_on"], name: "index_spree_products_on_available_on"
      t.index ["deleted_at"], name: "index_spree_products_on_deleted_at"
      t.index ["discontinue_on"], name: "index_spree_products_on_discontinue_on"
      t.index ["name"], name: "index_spree_products_on_name"
      t.index ["shipping_category_id"], name: "index_spree_products_on_shipping_category_id"
      t.index ["slug"], name: "index_spree_products_on_slug", unique: true
      t.index ["tax_category_id"], name: "index_spree_products_on_tax_category_id"
    end

    create_table "spree_products_stores", force: :cascade do |t|
      t.bigint "product_id"
      t.bigint "store_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["product_id", "store_id"], name: "index_spree_products_stores_on_product_id_and_store_id", unique: true
      t.index ["product_id"], name: "index_spree_products_stores_on_product_id"
      t.index ["store_id"], name: "index_spree_products_stores_on_store_id"
    end

    create_table "spree_products_taxons", force: :cascade do |t|
      t.bigint "product_id"
      t.bigint "taxon_id"
      t.integer "position"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["position"], name: "index_spree_products_taxons_on_position"
      t.index ["product_id", "taxon_id"], name: "index_spree_products_taxons_on_product_id_and_taxon_id", unique: true
      t.index ["product_id"], name: "index_spree_products_taxons_on_product_id"
      t.index ["taxon_id"], name: "index_spree_products_taxons_on_taxon_id"
    end

    create_table "spree_promotion_action_line_items", force: :cascade do |t|
      t.bigint "promotion_action_id"
      t.bigint "variant_id"
      t.integer "quantity", default: 1
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["promotion_action_id"], name: "index_spree_promotion_action_line_items_on_promotion_action_id"
      t.index ["variant_id"], name: "index_spree_promotion_action_line_items_on_variant_id"
    end

    create_table "spree_promotion_actions", force: :cascade do |t|
      t.bigint "promotion_id"
      t.integer "position"
      t.string "type"
      t.datetime "deleted_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["deleted_at"], name: "index_spree_promotion_actions_on_deleted_at"
      t.index ["id", "type"], name: "index_spree_promotion_actions_on_id_and_type"
      t.index ["promotion_id"], name: "index_spree_promotion_actions_on_promotion_id"
    end

    create_table "spree_promotion_categories", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "code"
    end

    create_table "spree_promotion_rule_taxons", force: :cascade do |t|
      t.bigint "taxon_id"
      t.bigint "promotion_rule_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["promotion_rule_id"], name: "index_spree_promotion_rule_taxons_on_promotion_rule_id"
      t.index ["taxon_id"], name: "index_spree_promotion_rule_taxons_on_taxon_id"
    end

    create_table "spree_promotion_rule_users", force: :cascade do |t|
      t.bigint "user_id"
      t.bigint "promotion_rule_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["promotion_rule_id"], name: "index_promotion_rules_users_on_promotion_rule_id"
      t.index ["user_id", "promotion_rule_id"], name: "index_promotion_rules_users_on_user_id_and_promotion_rule_id"
    end

    create_table "spree_promotion_rules", force: :cascade do |t|
      t.bigint "promotion_id"
      t.bigint "user_id"
      t.bigint "product_group_id"
      t.string "type"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "code"
      t.text "preferences"
      t.index ["product_group_id"], name: "index_promotion_rules_on_product_group_id"
      t.index ["promotion_id"], name: "index_spree_promotion_rules_on_promotion_id"
      t.index ["user_id"], name: "index_promotion_rules_on_user_id"
    end

    create_table "spree_promotions", force: :cascade do |t|
      t.string "description"
      t.datetime "expires_at"
      t.datetime "starts_at"
      t.string "name"
      t.string "type"
      t.integer "usage_limit"
      t.string "match_policy", default: "all"
      t.string "code"
      t.boolean "advertise", default: false
      t.string "path"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "promotion_category_id"
      t.index ["advertise"], name: "index_spree_promotions_on_advertise"
      t.index ["code"], name: "index_spree_promotions_on_code"
      t.index ["expires_at"], name: "index_spree_promotions_on_expires_at"
      t.index ["id", "type"], name: "index_spree_promotions_on_id_and_type"
      t.index ["path"], name: "index_spree_promotions_on_path"
      t.index ["promotion_category_id"], name: "index_spree_promotions_on_promotion_category_id"
      t.index ["starts_at"], name: "index_spree_promotions_on_starts_at"
    end

    create_table "spree_promotions_stores", force: :cascade do |t|
      t.bigint "promotion_id"
      t.bigint "store_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["promotion_id", "store_id"], name: "index_spree_promotions_stores_on_promotion_id_and_store_id", unique: true
      t.index ["promotion_id"], name: "index_spree_promotions_stores_on_promotion_id"
      t.index ["store_id"], name: "index_spree_promotions_stores_on_store_id"
    end

    create_table "spree_properties", force: :cascade do |t|
      t.string "name"
      t.string "presentation", null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "filterable", default: false, null: false
      t.string "filter_param"
      t.index ["filter_param"], name: "index_spree_properties_on_filter_param"
      t.index ["filterable"], name: "index_spree_properties_on_filterable"
      t.index ["name"], name: "index_spree_properties_on_name"
    end

    create_table "spree_property_prototypes", force: :cascade do |t|
      t.bigint "prototype_id"
      t.bigint "property_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["property_id"], name: "index_spree_property_prototypes_on_property_id"
      t.index ["prototype_id", "property_id"], name: "index_property_prototypes_on_prototype_id_and_property_id", unique: true
      t.index ["prototype_id"], name: "index_spree_property_prototypes_on_prototype_id"
    end

    create_table "spree_prototype_taxons", force: :cascade do |t|
      t.bigint "taxon_id"
      t.bigint "prototype_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["prototype_id", "taxon_id"], name: "index_spree_prototype_taxons_on_prototype_id_and_taxon_id"
      t.index ["prototype_id"], name: "index_spree_prototype_taxons_on_prototype_id"
      t.index ["taxon_id"], name: "index_spree_prototype_taxons_on_taxon_id"
    end

    create_table "spree_prototypes", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
    end

    create_table "spree_refund_reasons", force: :cascade do |t|
      t.string "name"
      t.boolean "active", default: true
      t.boolean "mutable", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["name"], name: "index_spree_refund_reasons_on_name", unique: true
    end

    create_table "spree_refunds", force: :cascade do |t|
      t.bigint "payment_id"
      t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
      t.string "transaction_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "refund_reason_id"
      t.bigint "reimbursement_id"
      t.index ["payment_id"], name: "index_spree_refunds_on_payment_id"
      t.index ["refund_reason_id"], name: "index_refunds_on_refund_reason_id"
      t.index ["reimbursement_id"], name: "index_spree_refunds_on_reimbursement_id"
    end

    create_table "spree_reimbursement_credits", force: :cascade do |t|
      t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
      t.bigint "reimbursement_id"
      t.bigint "creditable_id"
      t.string "creditable_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["creditable_id", "creditable_type"], name: "index_reimbursement_credits_on_creditable_id_and_type"
      t.index ["reimbursement_id"], name: "index_spree_reimbursement_credits_on_reimbursement_id"
    end

    create_table "spree_reimbursement_types", force: :cascade do |t|
      t.string "name"
      t.boolean "active", default: true
      t.boolean "mutable", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "type"
      t.index ["name"], name: "index_spree_reimbursement_types_on_name", unique: true
      t.index ["type"], name: "index_spree_reimbursement_types_on_type"
    end

    create_table "spree_reimbursements", force: :cascade do |t|
      t.string "number"
      t.string "reimbursement_status"
      t.bigint "customer_return_id"
      t.bigint "order_id"
      t.decimal "total", precision: 10, scale: 2
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["customer_return_id"], name: "index_spree_reimbursements_on_customer_return_id"
      t.index ["number"], name: "index_spree_reimbursements_on_number", unique: true
      t.index ["order_id"], name: "index_spree_reimbursements_on_order_id"
    end

    create_table "spree_return_authorization_reasons", force: :cascade do |t|
      t.string "name"
      t.boolean "active", default: true
      t.boolean "mutable", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["name"], name: "index_spree_return_authorization_reasons_on_name", unique: true
    end

    create_table "spree_return_authorizations", force: :cascade do |t|
      t.string "number"
      t.string "state"
      t.bigint "order_id"
      t.text "memo"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.bigint "stock_location_id"
      t.bigint "return_authorization_reason_id"
      t.index ["number"], name: "index_spree_return_authorizations_on_number", unique: true
      t.index ["order_id"], name: "index_spree_return_authorizations_on_order_id"
      t.index ["return_authorization_reason_id"], name: "index_return_authorizations_on_return_authorization_reason_id"
      t.index ["stock_location_id"], name: "index_spree_return_authorizations_on_stock_location_id"
    end

    create_table "spree_return_items", force: :cascade do |t|
      t.bigint "return_authorization_id"
      t.bigint "inventory_unit_id"
      t.bigint "exchange_variant_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
      t.decimal "included_tax_total", precision: 12, scale: 4, default: "0.0", null: false
      t.decimal "additional_tax_total", precision: 12, scale: 4, default: "0.0", null: false
      t.string "reception_status"
      t.string "acceptance_status"
      t.bigint "customer_return_id"
      t.bigint "reimbursement_id"
      t.text "acceptance_status_errors"
      t.bigint "preferred_reimbursement_type_id"
      t.bigint "override_reimbursement_type_id"
      t.boolean "resellable", default: true, null: false
      t.index ["customer_return_id"], name: "index_return_items_on_customer_return_id"
      t.index ["exchange_variant_id"], name: "index_spree_return_items_on_exchange_variant_id"
      t.index ["inventory_unit_id"], name: "index_spree_return_items_on_inventory_unit_id"
      t.index ["override_reimbursement_type_id"], name: "index_spree_return_items_on_override_reimbursement_type_id"
      t.index ["preferred_reimbursement_type_id"], name: "index_spree_return_items_on_preferred_reimbursement_type_id"
      t.index ["reimbursement_id"], name: "index_spree_return_items_on_reimbursement_id"
      t.index ["return_authorization_id"], name: "index_spree_return_items_on_return_authorization_id"
    end

    create_table "spree_role_users", force: :cascade do |t|
      t.bigint "role_id"
      t.bigint "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["role_id"], name: "index_spree_role_users_on_role_id"
      t.index ["user_id"], name: "index_spree_role_users_on_user_id"
    end

    create_table "spree_roles", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["name"], name: "index_spree_roles_on_name", unique: true
    end

    create_table "spree_shipments", force: :cascade do |t|
      t.string "tracking"
      t.string "number"
      t.decimal "cost", precision: 10, scale: 2, default: "0.0"
      t.datetime "shipped_at"
      t.bigint "order_id"
      t.bigint "address_id"
      t.string "state"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "stock_location_id"
      t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
      t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
      t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
      t.index ["address_id"], name: "index_spree_shipments_on_address_id"
      t.index ["number"], name: "index_spree_shipments_on_number", unique: true
      t.index ["order_id"], name: "index_spree_shipments_on_order_id"
      t.index ["stock_location_id"], name: "index_spree_shipments_on_stock_location_id"
    end

    create_table "spree_shipping_categories", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["name"], name: "index_spree_shipping_categories_on_name"
    end

    create_table "spree_shipping_method_categories", force: :cascade do |t|
      t.bigint "shipping_method_id", null: false
      t.bigint "shipping_category_id", null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["shipping_category_id", "shipping_method_id"], name: "unique_spree_shipping_method_categories", unique: true
      t.index ["shipping_category_id"], name: "index_spree_shipping_method_categories_on_shipping_category_id"
      t.index ["shipping_method_id"], name: "index_spree_shipping_method_categories_on_shipping_method_id"
    end

    create_table "spree_shipping_method_zones", force: :cascade do |t|
      t.bigint "shipping_method_id"
      t.bigint "zone_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["shipping_method_id"], name: "index_spree_shipping_method_zones_on_shipping_method_id"
      t.index ["zone_id"], name: "index_spree_shipping_method_zones_on_zone_id"
    end

    create_table "spree_shipping_methods", force: :cascade do |t|
      t.string "name"
      t.string "display_on"
      t.datetime "deleted_at"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "tracking_url"
      t.string "admin_name"
      t.bigint "tax_category_id"
      t.string "code"
      t.index ["deleted_at"], name: "index_spree_shipping_methods_on_deleted_at"
      t.index ["tax_category_id"], name: "index_spree_shipping_methods_on_tax_category_id"
    end

    create_table "spree_shipping_rates", force: :cascade do |t|
      t.bigint "shipment_id"
      t.bigint "shipping_method_id"
      t.boolean "selected", default: false
      t.decimal "cost", precision: 8, scale: 2, default: "0.0"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "tax_rate_id"
      t.index ["selected"], name: "index_spree_shipping_rates_on_selected"
      t.index ["shipment_id", "shipping_method_id"], name: "spree_shipping_rates_join_index", unique: true
      t.index ["shipment_id"], name: "index_spree_shipping_rates_on_shipment_id"
      t.index ["shipping_method_id"], name: "index_spree_shipping_rates_on_shipping_method_id"
      t.index ["tax_rate_id"], name: "index_spree_shipping_rates_on_tax_rate_id"
    end

    create_table "spree_state_changes", force: :cascade do |t|
      t.string "name"
      t.string "previous_state"
      t.bigint "stateful_id"
      t.bigint "user_id"
      t.string "stateful_type"
      t.string "next_state"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["stateful_id", "stateful_type"], name: "index_spree_state_changes_on_stateful_id_and_stateful_type"
    end

    create_table "spree_states", force: :cascade do |t|
      t.string "name"
      t.string "abbr"
      t.bigint "country_id"
      t.datetime "updated_at"
      t.datetime "created_at"
      t.index ["country_id"], name: "index_spree_states_on_country_id"
    end

    create_table "spree_stock_items", force: :cascade do |t|
      t.bigint "stock_location_id"
      t.bigint "variant_id"
      t.integer "count_on_hand", default: 0, null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "backorderable", default: false
      t.datetime "deleted_at"
      t.index ["backorderable"], name: "index_spree_stock_items_on_backorderable"
      t.index ["deleted_at"], name: "index_spree_stock_items_on_deleted_at"
      t.index ["stock_location_id", "variant_id"], name: "stock_item_by_loc_and_var_id"
      t.index ["stock_location_id"], name: "index_spree_stock_items_on_stock_location_id"
      t.index ["variant_id"], name: "index_spree_stock_items_on_variant_id"
    end

    create_table "spree_stock_locations", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.boolean "default", default: false, null: false
      t.string "address1"
      t.string "address2"
      t.string "city"
      t.bigint "state_id"
      t.string "state_name"
      t.bigint "country_id"
      t.string "zipcode"
      t.string "phone"
      t.boolean "active", default: true
      t.boolean "backorderable_default", default: false
      t.boolean "propagate_all_variants", default: true
      t.string "admin_name"
      t.index ["active"], name: "index_spree_stock_locations_on_active"
      t.index ["backorderable_default"], name: "index_spree_stock_locations_on_backorderable_default"
      t.index ["country_id"], name: "index_spree_stock_locations_on_country_id"
      t.index ["propagate_all_variants"], name: "index_spree_stock_locations_on_propagate_all_variants"
      t.index ["state_id"], name: "index_spree_stock_locations_on_state_id"
    end

    create_table "spree_stock_movements", force: :cascade do |t|
      t.bigint "stock_item_id"
      t.integer "quantity", default: 0
      t.string "action"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "originator_type"
      t.bigint "originator_id"
      t.index ["originator_id", "originator_type"], name: "index_stock_movements_on_originator_id_and_originator_type"
      t.index ["stock_item_id"], name: "index_spree_stock_movements_on_stock_item_id"
    end

    create_table "spree_stock_transfers", force: :cascade do |t|
      t.string "type"
      t.string "reference"
      t.bigint "source_location_id"
      t.bigint "destination_location_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "number"
      t.index ["destination_location_id"], name: "index_spree_stock_transfers_on_destination_location_id"
      t.index ["number"], name: "index_spree_stock_transfers_on_number", unique: true
      t.index ["source_location_id"], name: "index_spree_stock_transfers_on_source_location_id"
    end

    create_table "spree_store_credit_categories", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
    end

    create_table "spree_store_credit_events", force: :cascade do |t|
      t.bigint "store_credit_id", null: false
      t.string "action", null: false
      t.decimal "amount", precision: 8, scale: 2
      t.string "authorization_code", null: false
      t.decimal "user_total_amount", precision: 8, scale: 2, default: "0.0", null: false
      t.bigint "originator_id"
      t.string "originator_type"
      t.datetime "deleted_at"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["originator_id", "originator_type"], name: "spree_store_credit_events_originator"
      t.index ["store_credit_id"], name: "index_spree_store_credit_events_on_store_credit_id"
    end

    create_table "spree_store_credit_types", force: :cascade do |t|
      t.string "name"
      t.integer "priority"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["priority"], name: "index_spree_store_credit_types_on_priority"
    end

    create_table "spree_store_credits", force: :cascade do |t|
      t.bigint "user_id"
      t.bigint "category_id"
      t.bigint "created_by_id"
      t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
      t.decimal "amount_used", precision: 8, scale: 2, default: "0.0", null: false
      t.text "memo"
      t.datetime "deleted_at"
      t.string "currency"
      t.decimal "amount_authorized", precision: 8, scale: 2, default: "0.0", null: false
      t.bigint "originator_id"
      t.string "originator_type"
      t.bigint "type_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.bigint "store_id"
      t.index ["deleted_at"], name: "index_spree_store_credits_on_deleted_at"
      t.index ["originator_id", "originator_type"], name: "spree_store_credits_originator"
      t.index ["store_id"], name: "index_spree_store_credits_on_store_id"
      t.index ["type_id"], name: "index_spree_store_credits_on_type_id"
      t.index ["user_id"], name: "index_spree_store_credits_on_user_id"
    end

    create_table "spree_stores", force: :cascade do |t|
      t.string "name"
      t.string "url"
      t.text "meta_description"
      t.text "meta_keywords"
      t.string "seo_title"
      t.string "mail_from_address"
      t.string "default_currency"
      t.string "code"
      t.boolean "default", default: false, null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "supported_currencies"
      t.string "facebook"
      t.string "twitter"
      t.string "instagram"
      t.string "default_locale"
      t.string "customer_support_email"
      t.bigint "default_country_id"
      t.text "description"
      t.text "address"
      t.string "contact_phone"
      t.string "new_order_notifications_email"
      t.bigint "checkout_zone_id"
      t.string "seo_robots"
      t.string "supported_locales"
      t.index ["code"], name: "index_spree_stores_on_code", unique: true
      t.index ["default"], name: "index_spree_stores_on_default"
      t.index ["url"], name: "index_spree_stores_on_url"
    end

    create_table "spree_tax_categories", force: :cascade do |t|
      t.string "name"
      t.string "description"
      t.boolean "is_default", default: false
      t.datetime "deleted_at"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "tax_code"
      t.index ["deleted_at"], name: "index_spree_tax_categories_on_deleted_at"
      t.index ["is_default"], name: "index_spree_tax_categories_on_is_default"
    end

    create_table "spree_tax_rates", force: :cascade do |t|
      t.decimal "amount", precision: 8, scale: 5
      t.bigint "zone_id"
      t.bigint "tax_category_id"
      t.boolean "included_in_price", default: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "name"
      t.boolean "show_rate_in_label", default: true
      t.datetime "deleted_at"
      t.index ["deleted_at"], name: "index_spree_tax_rates_on_deleted_at"
      t.index ["included_in_price"], name: "index_spree_tax_rates_on_included_in_price"
      t.index ["show_rate_in_label"], name: "index_spree_tax_rates_on_show_rate_in_label"
      t.index ["tax_category_id"], name: "index_spree_tax_rates_on_tax_category_id"
      t.index ["zone_id"], name: "index_spree_tax_rates_on_zone_id"
    end

    create_table "spree_taxonomies", force: :cascade do |t|
      t.string "name", null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.integer "position", default: 0
      t.bigint "store_id"
      t.index ["name", "store_id"], name: "index_spree_taxonomies_on_name_and_store_id", unique: true
      t.index ["position"], name: "index_spree_taxonomies_on_position"
      t.index ["store_id"], name: "index_spree_taxonomies_on_store_id"
    end

    create_table "spree_taxons", force: :cascade do |t|
      t.bigint "parent_id"
      t.integer "position", default: 0
      t.string "name", null: false
      t.string "permalink"
      t.bigint "taxonomy_id"
      t.bigint "lft"
      t.bigint "rgt"
      t.text "description"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "meta_title"
      t.string "meta_description"
      t.string "meta_keywords"
      t.integer "depth"
      t.boolean "hide_from_nav", default: false
      t.index ["lft"], name: "index_spree_taxons_on_lft"
      t.index ["name", "parent_id", "taxonomy_id"], name: "index_spree_taxons_on_name_and_parent_id_and_taxonomy_id", unique: true
      t.index ["name"], name: "index_spree_taxons_on_name"
      t.index ["parent_id"], name: "index_taxons_on_parent_id"
      t.index ["permalink", "parent_id", "taxonomy_id"], name: "index_spree_taxons_on_permalink_and_parent_id_and_taxonomy_id", unique: true
      t.index ["permalink"], name: "index_taxons_on_permalink"
      t.index ["position"], name: "index_spree_taxons_on_position"
      t.index ["rgt"], name: "index_spree_taxons_on_rgt"
      t.index ["taxonomy_id"], name: "index_taxons_on_taxonomy_id"
    end

    create_table "spree_trackers", force: :cascade do |t|
      t.string "analytics_id"
      t.boolean "active", default: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.integer "engine", default: 0, null: false
      t.index ["active"], name: "index_spree_trackers_on_active"
    end

    create_table "spree_users", force: :cascade do |t|
      t.string "encrypted_password", limit: 128
      t.string "password_salt", limit: 128
      t.string "email"
      t.string "remember_token"
      t.string "persistence_token"
      t.string "reset_password_token"
      t.string "perishable_token"
      t.integer "sign_in_count", default: 0, null: false
      t.integer "failed_attempts", default: 0, null: false
      t.datetime "last_request_at"
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string "current_sign_in_ip"
      t.string "last_sign_in_ip"
      t.string "login"
      t.bigint "ship_address_id"
      t.bigint "bill_address_id"
      t.string "authentication_token"
      t.string "unlock_token"
      t.datetime "locked_at"
      t.datetime "remember_created_at"
      t.datetime "reset_password_sent_at"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
    end

    create_table "spree_variants", force: :cascade do |t|
      t.string "sku", default: "", null: false
      t.decimal "weight", precision: 8, scale: 2, default: "0.0"
      t.decimal "height", precision: 8, scale: 2
      t.decimal "width", precision: 8, scale: 2
      t.decimal "depth", precision: 8, scale: 2
      t.datetime "deleted_at"
      t.boolean "is_master", default: false
      t.bigint "product_id"
      t.decimal "cost_price", precision: 10, scale: 2
      t.integer "position"
      t.string "cost_currency"
      t.boolean "track_inventory", default: true
      t.bigint "tax_category_id"
      t.datetime "updated_at", null: false
      t.datetime "discontinue_on"
      t.datetime "created_at", null: false
      t.index ["deleted_at"], name: "index_spree_variants_on_deleted_at"
      t.index ["discontinue_on"], name: "index_spree_variants_on_discontinue_on"
      t.index ["is_master"], name: "index_spree_variants_on_is_master"
      t.index ["position"], name: "index_spree_variants_on_position"
      t.index ["product_id"], name: "index_spree_variants_on_product_id"
      t.index ["sku"], name: "index_spree_variants_on_sku"
      t.index ["tax_category_id"], name: "index_spree_variants_on_tax_category_id"
      t.index ["track_inventory"], name: "index_spree_variants_on_track_inventory"
    end

    create_table "spree_zone_members", force: :cascade do |t|
      t.string "zoneable_type"
      t.bigint "zoneable_id"
      t.bigint "zone_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["zone_id"], name: "index_spree_zone_members_on_zone_id"
      t.index ["zoneable_id", "zoneable_type"], name: "index_spree_zone_members_on_zoneable_id_and_zoneable_type"
    end

    create_table "spree_zones", force: :cascade do |t|
      t.string "name"
      t.string "description"
      t.boolean "default_tax", default: false
      t.integer "zone_members_count", default: 0
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "kind", default: "state"
      t.index ["default_tax"], name: "index_spree_zones_on_default_tax"
      t.index ["kind"], name: "index_spree_zones_on_kind"
    end
  end
end
