# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_18_156042) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "locale", default: "en", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name", "locale"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "action_text_video_embeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "raw_html", null: false
    t.string "thumbnail_url", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.string "locale"
    t.string "scope"
    t.string "slug", null: false
    t.bigint "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["deleted_at"], name: "index_friendly_id_slugs_on_deleted_at"
    t.index ["locale"], name: "index_friendly_id_slugs_on_locale"
    t.index ["slug", "sluggable_type", "locale"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_locale"
    t.index ["slug", "sluggable_type", "scope", "locale"], name: "index_friendly_id_slugs_unique", unique: true
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "spree_addresses", force: :cascade do |t|
    t.string "address1"
    t.string "address2"
    t.string "alternative_phone"
    t.string "city"
    t.string "company"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "firstname"
    t.string "label"
    t.string "lastname"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "phone"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.boolean "quick_checkout", default: false
    t.bigint "state_id"
    t.string "state_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "zipcode"
    t.index ["country_id"], name: "index_spree_addresses_on_country_id"
    t.index ["deleted_at"], name: "index_spree_addresses_on_deleted_at"
    t.index ["firstname"], name: "index_addresses_on_firstname"
    t.index ["lastname"], name: "index_addresses_on_lastname"
    t.index ["quick_checkout"], name: "index_spree_addresses_on_quick_checkout"
    t.index ["state_id"], name: "index_spree_addresses_on_state_id"
    t.index ["user_id"], name: "index_spree_addresses_on_user_id"
  end

  create_table "spree_adjustments", force: :cascade do |t|
    t.bigint "adjustable_id"
    t.string "adjustable_type"
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.boolean "eligible", default: true
    t.boolean "included", default: false
    t.string "label"
    t.boolean "mandatory"
    t.bigint "order_id", null: false
    t.bigint "source_id"
    t.string "source_type"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["adjustable_id", "adjustable_type"], name: "index_spree_adjustments_on_adjustable_id_and_adjustable_type"
    t.index ["adjustable_type", "adjustable_id", "source_type"], name: "index_spree_adjustments_on_adjustable_and_source_type"
    t.index ["amount"], name: "index_spree_adjustments_on_amount"
    t.index ["eligible"], name: "index_spree_adjustments_on_eligible"
    t.index ["order_id", "eligible", "source_type"], name: "index_spree_adjustments_on_order_eligible_source_type"
    t.index ["order_id", "state"], name: "index_spree_adjustments_on_order_id_and_state"
    t.index ["order_id"], name: "index_spree_adjustments_on_order_id"
    t.index ["source_id", "source_type"], name: "index_spree_adjustments_on_source_id_and_source_type"
    t.index ["source_type"], name: "index_spree_adjustments_on_source_type"
  end

  create_table "spree_admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "login"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "selected_locale"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_spree_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_spree_admin_users_on_reset_password_token", unique: true
  end

  create_table "spree_api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.string "key_type", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "revoked_by_type"
    t.bigint "store_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_type", "created_by_id"], name: "index_spree_api_keys_on_created_by"
    t.index ["key_type"], name: "index_spree_api_keys_on_key_type"
    t.index ["revoked_by_type", "revoked_by_id"], name: "index_spree_api_keys_on_revoked_by"
    t.index ["store_id", "key_type"], name: "index_spree_api_keys_on_store_id_and_key_type"
    t.index ["store_id"], name: "index_spree_api_keys_on_store_id"
    t.index ["token"], name: "index_spree_api_keys_on_token", unique: true
  end

  create_table "spree_assets", force: :cascade do |t|
    t.text "alt"
    t.string "attachment_content_type"
    t.string "attachment_file_name"
    t.integer "attachment_file_size"
    t.integer "attachment_height"
    t.datetime "attachment_updated_at", precision: nil
    t.integer "attachment_width"
    t.datetime "created_at", precision: nil
    t.integer "position"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.string "session_id"
    t.string "type", limit: 75
    t.datetime "updated_at", precision: nil
    t.bigint "viewable_id"
    t.string "viewable_type"
    t.index ["position"], name: "index_spree_assets_on_position"
    t.index ["viewable_id"], name: "index_assets_on_viewable_id"
    t.index ["viewable_type", "type"], name: "index_assets_on_viewable_type_and_type"
  end

  create_table "spree_calculators", force: :cascade do |t|
    t.bigint "calculable_id"
    t.string "calculable_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "preferences"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["calculable_id", "calculable_type"], name: "index_spree_calculators_on_calculable_id_and_calculable_type"
    t.index ["deleted_at"], name: "index_spree_calculators_on_deleted_at"
    t.index ["id", "type"], name: "index_spree_calculators_on_id_and_type"
  end

  create_table "spree_countries", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "iso", null: false
    t.string "iso3", null: false
    t.string "iso_name"
    t.string "name"
    t.integer "numcode"
    t.boolean "states_required", default: false
    t.datetime "updated_at", precision: nil
    t.boolean "zipcode_required", default: true
    t.index ["iso"], name: "index_spree_countries_on_iso", unique: true
    t.index ["iso3"], name: "index_spree_countries_on_iso3", unique: true
    t.index ["iso_name"], name: "index_spree_countries_on_iso_name", unique: true
    t.index ["name"], name: "index_spree_countries_on_name", unique: true
  end

  create_table "spree_coupon_codes", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "order_id"
    t.bigint "promotion_id"
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_spree_coupon_codes_on_code", unique: true
    t.index ["deleted_at"], name: "index_spree_coupon_codes_on_deleted_at"
    t.index ["order_id"], name: "index_spree_coupon_codes_on_order_id"
    t.index ["promotion_id"], name: "index_spree_coupon_codes_on_promotion_id"
    t.index ["state"], name: "index_spree_coupon_codes_on_state"
  end

  create_table "spree_credit_cards", force: :cascade do |t|
    t.bigint "address_id"
    t.string "cc_type"
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "gateway_customer_id"
    t.string "gateway_customer_profile_id"
    t.string "gateway_payment_profile_id"
    t.string "last_digits"
    t.string "month"
    t.string "name"
    t.bigint "payment_method_id"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "year"
    t.index ["address_id"], name: "index_spree_credit_cards_on_address_id"
    t.index ["deleted_at"], name: "index_spree_credit_cards_on_deleted_at"
    t.index ["gateway_customer_id"], name: "index_spree_credit_cards_on_gateway_customer_id"
    t.index ["payment_method_id"], name: "index_spree_credit_cards_on_payment_method_id"
    t.index ["user_id"], name: "index_spree_credit_cards_on_user_id"
  end

  create_table "spree_custom_domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.boolean "status", default: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["store_id"], name: "index_spree_custom_domains_on_store_id"
    t.index ["url"], name: "index_spree_custom_domains_on_url", unique: true
  end

  create_table "spree_customer_group_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_group_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "user_type", null: false
    t.index ["customer_group_id", "user_id", "user_type"], name: "index_spree_customer_group_users_unique", unique: true
    t.index ["customer_group_id"], name: "index_spree_customer_group_users_on_customer_group_id"
    t.index ["user_type", "user_id"], name: "index_spree_customer_group_users_on_user"
  end

  create_table "spree_customer_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_customer_groups_on_deleted_at"
    t.index ["store_id", "name"], name: "index_spree_customer_groups_on_store_id_and_name", unique: true, where: "(deleted_at IS NULL)"
    t.index ["store_id"], name: "index_spree_customer_groups_on_store_id"
  end

  create_table "spree_customer_returns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "number"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "stock_location_id"
    t.bigint "store_id"
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_spree_customer_returns_on_number", unique: true
    t.index ["stock_location_id"], name: "index_spree_customer_returns_on_stock_location_id"
    t.index ["store_id"], name: "index_spree_customer_returns_on_store_id"
  end

  create_table "spree_data_feeds", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.bigint "store_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["store_id", "slug", "type"], name: "index_spree_data_feeds_on_store_id_and_slug_and_type"
    t.index ["store_id"], name: "index_spree_data_feeds_on_store_id"
  end

  create_table "spree_digital_links", force: :cascade do |t|
    t.integer "access_counter"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "digital_id"
    t.bigint "line_item_id"
    t.string "token"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["digital_id"], name: "index_spree_digital_links_on_digital_id"
    t.index ["line_item_id"], name: "index_spree_digital_links_on_line_item_id"
    t.index ["token"], name: "index_spree_digital_links_on_token", unique: true
  end

  create_table "spree_digitals", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "variant_id"
    t.index ["variant_id"], name: "index_spree_digitals_on_variant_id"
  end

  create_table "spree_exports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "format", null: false
    t.string "number", limit: 32, null: false
    t.jsonb "search_params"
    t.bigint "store_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["format"], name: "index_spree_exports_on_format"
    t.index ["number"], name: "index_spree_exports_on_number", unique: true
    t.index ["store_id"], name: "index_spree_exports_on_store_id"
    t.index ["user_id"], name: "index_spree_exports_on_user_id"
  end

  create_table "spree_gateway_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "payment_method_id", null: false
    t.string "profile_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["payment_method_id"], name: "index_spree_gateway_customers_on_payment_method_id"
    t.index ["user_id", "payment_method_id"], name: "index_spree_gateway_customers_on_user_id_and_payment_method_id", unique: true
    t.index ["user_id"], name: "index_spree_gateway_customers_on_user_id"
  end

  create_table "spree_gateways", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "environment", default: "development"
    t.string "name"
    t.text "preferences"
    t.string "server", default: "test"
    t.boolean "test_mode", default: true
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_spree_gateways_on_active"
    t.index ["test_mode"], name: "index_spree_gateways_on_test_mode"
  end

  create_table "spree_gift_card_batches", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "codes_count", default: 1, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", null: false
    t.date "expires_at"
    t.string "prefix"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_spree_gift_card_batches_on_created_by_id"
    t.index ["store_id"], name: "index_spree_gift_card_batches_on_store_id"
  end

  create_table "spree_gift_cards", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "amount_authorized", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "amount_used", precision: 10, scale: 2, default: "0.0", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", null: false
    t.date "expires_at"
    t.bigint "gift_card_batch_id"
    t.datetime "redeemed_at"
    t.string "state", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["code"], name: "index_spree_gift_cards_on_code", unique: true
    t.index ["created_by_id"], name: "index_spree_gift_cards_on_created_by_id"
    t.index ["expires_at"], name: "index_spree_gift_cards_on_expires_at"
    t.index ["gift_card_batch_id"], name: "index_spree_gift_cards_on_gift_card_batch_id"
    t.index ["redeemed_at"], name: "index_spree_gift_cards_on_redeemed_at"
    t.index ["state"], name: "index_spree_gift_cards_on_state"
    t.index ["store_id"], name: "index_spree_gift_cards_on_store_id"
    t.index ["user_id"], name: "index_spree_gift_cards_on_user_id"
  end

  create_table "spree_import_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_column"
    t.bigint "import_id", null: false
    t.string "schema_field", null: false
    t.datetime "updated_at", null: false
    t.index ["file_column"], name: "index_spree_import_mappings_on_file_column"
    t.index ["import_id", "schema_field"], name: "index_spree_import_mappings_on_import_id_and_schema_field", unique: true
    t.index ["import_id"], name: "index_spree_import_mappings_on_import_id"
  end

  create_table "spree_import_rows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data", null: false
    t.bigint "import_id", null: false
    t.bigint "item_id"
    t.string "item_type"
    t.integer "row_number", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.text "validation_errors"
    t.index ["import_id", "row_number"], name: "index_spree_import_rows_on_import_id_and_row_number", unique: true
    t.index ["import_id"], name: "index_spree_import_rows_on_import_id"
    t.index ["item_type", "item_id"], name: "index_spree_import_rows_on_item"
    t.index ["status"], name: "index_spree_import_rows_on_status"
  end

  create_table "spree_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "number", limit: 32, null: false
    t.bigint "owner_id", null: false
    t.string "owner_type", null: false
    t.text "preferences"
    t.text "processing_errors"
    t.integer "rows_count", default: 0, null: false
    t.string "status", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["number"], name: "index_spree_imports_on_number", unique: true
    t.index ["owner_type", "owner_id"], name: "index_spree_imports_on_owner"
    t.index ["status"], name: "index_spree_imports_on_status"
    t.index ["type"], name: "index_spree_imports_on_type"
    t.index ["user_id"], name: "index_spree_imports_on_user_id"
  end

  create_table "spree_integrations", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.text "preferences"
    t.bigint "store_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_spree_integrations_on_active"
    t.index ["store_id"], name: "index_spree_integrations_on_store_id"
    t.index ["type"], name: "index_spree_integrations_on_type"
  end

  create_table "spree_inventory_units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "line_item_id"
    t.bigint "order_id"
    t.bigint "original_return_item_id"
    t.boolean "pending", default: true
    t.integer "quantity", default: 1
    t.bigint "shipment_id"
    t.string "state"
    t.datetime "updated_at", null: false
    t.bigint "variant_id"
    t.index ["line_item_id"], name: "index_spree_inventory_units_on_line_item_id"
    t.index ["order_id"], name: "index_inventory_units_on_order_id"
    t.index ["original_return_item_id"], name: "index_spree_inventory_units_on_original_return_item_id"
    t.index ["shipment_id"], name: "index_inventory_units_on_shipment_id"
    t.index ["variant_id"], name: "index_inventory_units_on_variant_id"
  end

  create_table "spree_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", null: false
    t.datetime "expires_at"
    t.bigint "invitee_id"
    t.string "invitee_type"
    t.bigint "inviter_id", null: false
    t.string "inviter_type", null: false
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.bigint "role_id", null: false
    t.string "status", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_invitations_on_deleted_at"
    t.index ["email"], name: "index_spree_invitations_on_email"
    t.index ["expires_at"], name: "index_spree_invitations_on_expires_at"
    t.index ["invitee_type", "invitee_id"], name: "index_spree_invitations_on_invitee"
    t.index ["inviter_type", "inviter_id"], name: "index_spree_invitations_on_inviter"
    t.index ["resource_type", "resource_id"], name: "index_spree_invitations_on_resource"
    t.index ["role_id"], name: "index_spree_invitations_on_role_id"
    t.index ["status"], name: "index_spree_invitations_on_status"
    t.index ["token"], name: "index_spree_invitations_on_token", unique: true
  end

  create_table "spree_line_items", force: :cascade do |t|
    t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "cost_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "currency"
    t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "order_id"
    t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "price_list_id"
    t.jsonb "private_metadata"
    t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
    t.jsonb "public_metadata"
    t.integer "quantity", null: false
    t.bigint "tax_category_id"
    t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "variant_id"
    t.index ["order_id"], name: "index_spree_line_items_on_order_id"
    t.index ["price_list_id"], name: "index_spree_line_items_on_price_list_id"
    t.index ["tax_category_id"], name: "index_spree_line_items_on_tax_category_id"
    t.index ["variant_id"], name: "index_spree_line_items_on_variant_id"
  end

  create_table "spree_log_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.bigint "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["source_id", "source_type"], name: "index_spree_log_entries_on_source_id_and_source_type"
  end

  create_table "spree_metafield_definitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_on", default: "both", null: false
    t.string "key", null: false
    t.string "metafield_type", null: false
    t.string "name", null: false
    t.string "namespace", null: false
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.index ["display_on"], name: "index_spree_metafield_definitions_on_display_on"
    t.index ["namespace", "key"], name: "index_spree_metafield_definitions_on_namespace_and_key"
    t.index ["resource_type", "namespace", "key"], name: "idx_on_resource_type_namespace_key_60c784bc3e", unique: true
    t.index ["resource_type"], name: "index_spree_metafield_definitions_on_resource_type"
  end

  create_table "spree_metafields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "metafield_definition_id", null: false
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["metafield_definition_id"], name: "index_spree_metafields_on_metafield_definition_id"
    t.index ["resource_type", "resource_id", "metafield_definition_id"], name: "index_metafields_on_resource_and_definition", unique: true
    t.index ["resource_type", "resource_id"], name: "index_spree_metafields_on_resource"
    t.index ["type"], name: "index_spree_metafields_on_type"
  end

  create_table "spree_newsletter_subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "verification_token"
    t.datetime "verified_at"
    t.index ["email"], name: "index_spree_newsletter_subscribers_on_email", unique: true
    t.index ["user_id"], name: "index_spree_newsletter_subscribers_on_user_id"
    t.index ["verification_token"], name: "index_spree_newsletter_subscribers_on_verification_token", unique: true
    t.index ["verified_at"], name: "index_spree_newsletter_subscribers_on_verified_at"
  end

  create_table "spree_option_type_prototypes", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "option_type_id"
    t.bigint "prototype_id"
    t.datetime "updated_at", precision: nil
    t.index ["option_type_id"], name: "index_spree_option_type_prototypes_on_option_type_id"
    t.index ["prototype_id", "option_type_id"], name: "spree_option_type_prototypes_prototype_id_option_type_id", unique: true
    t.index ["prototype_id"], name: "index_spree_option_type_prototypes_on_prototype_id"
  end

  create_table "spree_option_type_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "presentation"
    t.bigint "spree_option_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_spree_option_type_translations_on_locale"
    t.index ["spree_option_type_id", "locale"], name: "unique_option_type_id_per_locale", unique: true
  end

  create_table "spree_option_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "filterable", default: true, null: false
    t.string "name", limit: 100
    t.integer "position", default: 0, null: false
    t.string "presentation", limit: 100
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
    t.index ["filterable"], name: "index_spree_option_types_on_filterable"
    t.index ["name"], name: "index_spree_option_types_on_name", unique: true
    t.index ["position"], name: "index_spree_option_types_on_position"
  end

  create_table "spree_option_value_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "presentation"
    t.bigint "spree_option_value_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_spree_option_value_translations_on_locale"
    t.index ["spree_option_value_id", "locale"], name: "unique_option_value_id_per_locale", unique: true
  end

  create_table "spree_option_value_variants", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "option_value_id"
    t.datetime "updated_at", precision: nil
    t.bigint "variant_id"
    t.index ["option_value_id"], name: "index_spree_option_value_variants_on_option_value_id"
    t.index ["variant_id", "option_value_id"], name: "index_option_values_variants_on_variant_id_and_option_value_id", unique: true
    t.index ["variant_id"], name: "index_spree_option_value_variants_on_variant_id"
  end

  create_table "spree_option_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "option_type_id"
    t.integer "position"
    t.string "presentation"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spree_option_values_on_name"
    t.index ["option_type_id", "name"], name: "index_spree_option_values_on_option_type_id_and_name", unique: true
    t.index ["option_type_id"], name: "index_spree_option_values_on_option_type_id"
    t.index ["position"], name: "index_spree_option_values_on_position"
  end

  create_table "spree_order_promotions", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "order_id"
    t.bigint "promotion_id"
    t.datetime "updated_at", precision: nil
    t.index ["order_id"], name: "index_spree_order_promotions_on_order_id"
    t.index ["promotion_id", "order_id"], name: "index_spree_order_promotions_on_promotion_id_and_order_id", unique: true
    t.index ["promotion_id"], name: "index_spree_order_promotions_on_promotion_id"
  end

  create_table "spree_orders", force: :cascade do |t|
    t.boolean "accept_marketing", default: false
    t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "approved_at", precision: nil
    t.bigint "approver_id"
    t.bigint "bill_address_id"
    t.datetime "canceled_at", precision: nil
    t.bigint "canceler_id"
    t.string "channel", default: "spree"
    t.datetime "completed_at", precision: nil
    t.boolean "confirmation_delivered", default: false
    t.boolean "considered_risky", default: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency"
    t.string "email"
    t.bigint "gift_card_id"
    t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
    t.text "internal_note"
    t.integer "item_count", default: 0
    t.decimal "item_total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "last_ip_address"
    t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "number", limit: 32
    t.string "payment_state"
    t.decimal "payment_total", precision: 10, scale: 2, default: "0.0"
    t.jsonb "private_metadata"
    t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
    t.jsonb "public_metadata"
    t.bigint "ship_address_id"
    t.string "shipment_state"
    t.decimal "shipment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.boolean "signup_for_an_account", default: false
    t.text "special_instructions"
    t.string "state"
    t.integer "state_lock_version", default: 0, null: false
    t.bigint "store_id"
    t.boolean "store_owner_notification_delivered"
    t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "token"
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["approver_id"], name: "index_spree_orders_on_approver_id"
    t.index ["bill_address_id"], name: "index_spree_orders_on_bill_address_id"
    t.index ["canceler_id"], name: "index_spree_orders_on_canceler_id"
    t.index ["completed_at"], name: "index_spree_orders_on_completed_at"
    t.index ["confirmation_delivered"], name: "index_spree_orders_on_confirmation_delivered"
    t.index ["considered_risky"], name: "index_spree_orders_on_considered_risky"
    t.index ["created_by_id"], name: "index_spree_orders_on_created_by_id"
    t.index ["gift_card_id"], name: "index_spree_orders_on_gift_card_id"
    t.index ["number"], name: "index_spree_orders_on_number", unique: true
    t.index ["ship_address_id"], name: "index_spree_orders_on_ship_address_id"
    t.index ["store_id"], name: "index_spree_orders_on_store_id"
    t.index ["token"], name: "index_spree_orders_on_token"
    t.index ["user_id", "created_by_id"], name: "index_spree_orders_on_user_id_and_created_by_id"
  end

  create_table "spree_payment_capture_events", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "payment_id"
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_spree_payment_capture_events_on_payment_id"
  end

  create_table "spree_payment_methods", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "auto_capture"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "display_on", default: "both"
    t.string "name"
    t.integer "position", default: 0
    t.text "preferences"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.jsonb "settings"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["id", "type"], name: "index_spree_payment_methods_on_id_and_type"
  end

  create_table "spree_payment_methods_stores", id: false, force: :cascade do |t|
    t.bigint "payment_method_id"
    t.bigint "store_id"
    t.index ["payment_method_id", "store_id"], name: "payment_mentod_id_store_id_unique_index", unique: true
    t.index ["payment_method_id"], name: "index_spree_payment_methods_stores_on_payment_method_id"
    t.index ["store_id"], name: "index_spree_payment_methods_stores_on_store_id"
  end

  create_table "spree_payment_sessions", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "customer_external_id"
    t.bigint "customer_id"
    t.datetime "deleted_at"
    t.datetime "expires_at"
    t.jsonb "external_data"
    t.string "external_id", null: false
    t.bigint "order_id", null: false
    t.bigint "payment_method_id", null: false
    t.string "status", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_spree_payment_sessions_on_customer_id"
    t.index ["deleted_at"], name: "index_spree_payment_sessions_on_deleted_at"
    t.index ["expires_at"], name: "index_spree_payment_sessions_on_expires_at"
    t.index ["external_id"], name: "index_spree_payment_sessions_on_external_id"
    t.index ["order_id", "payment_method_id", "external_id"], name: "idx_payment_sessions_order_method_external", unique: true
    t.index ["order_id"], name: "index_spree_payment_sessions_on_order_id"
    t.index ["payment_method_id"], name: "index_spree_payment_sessions_on_payment_method_id"
    t.index ["status"], name: "index_spree_payment_sessions_on_status"
    t.index ["type"], name: "index_spree_payment_sessions_on_type"
  end

  create_table "spree_payment_setup_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.datetime "deleted_at"
    t.string "external_client_secret"
    t.jsonb "external_data"
    t.string "external_id"
    t.bigint "payment_method_id", null: false
    t.bigint "payment_source_id"
    t.string "payment_source_type"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_spree_payment_setup_sessions_on_customer_id"
    t.index ["deleted_at"], name: "index_spree_payment_setup_sessions_on_deleted_at"
    t.index ["external_id", "payment_method_id"], name: "idx_spree_pss_unique_external_id_per_pm", unique: true
    t.index ["payment_method_id"], name: "index_spree_payment_setup_sessions_on_payment_method_id"
    t.index ["payment_source_type", "payment_source_id"], name: "idx_spree_pss_on_payment_source"
    t.index ["status"], name: "index_spree_payment_setup_sessions_on_status"
  end

  create_table "spree_payment_sources", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "gateway_customer_profile_id"
    t.string "gateway_payment_profile_id"
    t.bigint "payment_method_id"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["payment_method_id"], name: "index_spree_payment_sources_on_payment_method_id"
    t.index ["type", "gateway_payment_profile_id"], name: "index_payment_sources_on_type_and_gateway_payment_profile_id", unique: true
    t.index ["type"], name: "index_spree_payment_sources_on_type"
    t.index ["user_id"], name: "index_spree_payment_sources_on_user_id"
  end

  create_table "spree_payments", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "avs_response"
    t.datetime "created_at", null: false
    t.string "cvv_response_code"
    t.string "cvv_response_message"
    t.string "number"
    t.bigint "order_id"
    t.bigint "payment_method_id"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.string "response_code"
    t.bigint "source_id"
    t.string "source_type"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_spree_payments_on_number", unique: true
    t.index ["order_id"], name: "index_spree_payments_on_order_id"
    t.index ["payment_method_id"], name: "index_spree_payments_on_payment_method_id"
    t.index ["source_id", "source_type"], name: "index_spree_payments_on_source_id_and_source_type"
  end

  create_table "spree_policies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "owner_type", "slug"], name: "index_spree_policies_on_owner_id_and_owner_type_and_slug", unique: true
    t.index ["owner_type", "owner_id"], name: "index_spree_policies_on_owner"
  end

  create_table "spree_policy_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "name"
    t.bigint "spree_policy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["spree_policy_id", "locale"], name: "index_spree_policy_translations_on_spree_policy_id_and_locale", unique: true
    t.index ["spree_policy_id"], name: "index_spree_policy_translations_on_spree_policy_id"
  end

  create_table "spree_post_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.bigint "store_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug", "store_id"], name: "index_spree_post_categories_on_slug_and_store_id", unique: true
    t.index ["store_id"], name: "index_spree_post_categories_on_store_id"
  end

  create_table "spree_posts", force: :cascade do |t|
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "meta_description"
    t.string "meta_title"
    t.bigint "post_category_id"
    t.datetime "published_at", precision: nil
    t.string "slug", null: false
    t.bigint "store_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_spree_posts_on_author_id"
    t.index ["post_category_id"], name: "index_spree_posts_on_post_category_id"
    t.index ["store_id"], name: "index_spree_posts_on_store_id"
    t.index ["title"], name: "index_spree_posts_on_title"
  end

  create_table "spree_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_spree_preferences_on_key", unique: true
  end

  create_table "spree_price_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "ends_at"
    t.string "match_policy", default: "all", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "starts_at"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_price_lists_on_deleted_at"
    t.index ["position"], name: "index_spree_price_lists_on_position"
    t.index ["starts_at", "ends_at"], name: "index_spree_price_lists_on_starts_at_and_ends_at"
    t.index ["status"], name: "index_spree_price_lists_on_status"
    t.index ["store_id", "status", "position"], name: "index_spree_price_lists_on_store_id_and_status_and_position"
    t.index ["store_id"], name: "index_spree_price_lists_on_store_id"
  end

  create_table "spree_price_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "preferences"
    t.bigint "price_list_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["price_list_id", "type"], name: "index_spree_price_rules_on_price_list_id_and_type"
    t.index ["price_list_id"], name: "index_spree_price_rules_on_price_list_id"
    t.index ["type"], name: "index_spree_price_rules_on_type"
  end

  create_table "spree_prices", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "compare_at_amount", precision: 10, scale: 2
    t.datetime "created_at", precision: nil, null: false
    t.string "currency"
    t.datetime "deleted_at", precision: nil
    t.bigint "price_list_id"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "variant_id", null: false
    t.index ["deleted_at"], name: "index_spree_prices_on_deleted_at"
    t.index ["price_list_id"], name: "index_spree_prices_on_price_list_id"
    t.index ["variant_id", "currency", "price_list_id"], name: "index_spree_prices_on_variant_currency_price_list", unique: true, where: "((price_list_id IS NOT NULL) AND (deleted_at IS NULL) AND (amount IS NOT NULL))"
    t.index ["variant_id", "currency"], name: "index_spree_prices_on_variant_id_and_currency", unique: true, where: "((price_list_id IS NULL) AND (deleted_at IS NULL) AND (amount IS NOT NULL))"
    t.index ["variant_id"], name: "index_spree_prices_on_variant_id"
  end

  create_table "spree_product_option_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_type_id"
    t.integer "position"
    t.bigint "product_id"
    t.datetime "updated_at", null: false
    t.index ["option_type_id"], name: "index_spree_product_option_types_on_option_type_id"
    t.index ["position"], name: "index_spree_product_option_types_on_position"
    t.index ["product_id"], name: "index_spree_product_option_types_on_product_id"
  end

  create_table "spree_product_promotion_rules", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "product_id"
    t.bigint "promotion_rule_id"
    t.datetime "updated_at", precision: nil
    t.index ["product_id", "promotion_rule_id"], name: "idx_on_product_id_promotion_rule_id_aaea0385c9", unique: true
    t.index ["product_id"], name: "index_products_promotion_rules_on_product_id"
    t.index ["promotion_rule_id", "product_id"], name: "index_products_promotion_rules_on_promotion_rule_and_product"
  end

  create_table "spree_product_properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "filter_param"
    t.integer "position", default: 0
    t.bigint "product_id"
    t.bigint "property_id"
    t.boolean "show_property", default: true
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["filter_param"], name: "index_spree_product_properties_on_filter_param"
    t.index ["position"], name: "index_spree_product_properties_on_position"
    t.index ["product_id"], name: "index_product_properties_on_product_id"
    t.index ["property_id", "product_id"], name: "index_spree_product_properties_on_property_id_and_product_id", unique: true
    t.index ["property_id"], name: "index_spree_product_properties_on_property_id"
  end

  create_table "spree_product_property_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.bigint "spree_product_property_id", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["locale"], name: "index_spree_product_property_translations_on_locale"
    t.index ["spree_product_property_id", "locale"], name: "unique_product_property_id_per_locale", unique: true
  end

  create_table "spree_product_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "locale", null: false
    t.text "meta_description"
    t.string "meta_keywords"
    t.string "meta_title"
    t.string "name"
    t.string "slug"
    t.bigint "spree_product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_product_translations_on_deleted_at"
    t.index ["locale", "slug"], name: "unique_slug_per_locale", unique: true
    t.index ["locale"], name: "index_spree_product_translations_on_locale"
    t.index ["spree_product_id", "locale"], name: "unique_product_id_per_locale", unique: true
  end

  create_table "spree_products", force: :cascade do |t|
    t.datetime "available_on", precision: nil
    t.integer "classification_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.datetime "discontinue_on", precision: nil
    t.datetime "make_active_at", precision: nil
    t.text "meta_description"
    t.string "meta_keywords"
    t.string "meta_title"
    t.string "name", default: "", null: false
    t.jsonb "private_metadata"
    t.boolean "promotionable", default: true
    t.jsonb "public_metadata"
    t.bigint "shipping_category_id"
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.bigint "tax_category_id"
    t.bigint "thumbnail_id"
    t.integer "total_image_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "variant_count", default: 0, null: false
    t.index ["available_on"], name: "index_spree_products_on_available_on"
    t.index ["classification_count"], name: "index_spree_products_on_classification_count"
    t.index ["deleted_at"], name: "index_spree_products_on_deleted_at"
    t.index ["discontinue_on"], name: "index_spree_products_on_discontinue_on"
    t.index ["make_active_at"], name: "index_spree_products_on_make_active_at"
    t.index ["name"], name: "index_spree_products_on_name"
    t.index ["promotionable"], name: "index_spree_products_on_promotionable"
    t.index ["shipping_category_id"], name: "index_spree_products_on_shipping_category_id"
    t.index ["slug"], name: "index_spree_products_on_slug", unique: true
    t.index ["status", "deleted_at"], name: "index_spree_products_on_status_and_deleted_at"
    t.index ["status"], name: "index_spree_products_on_status"
    t.index ["tax_category_id"], name: "index_spree_products_on_tax_category_id"
    t.index ["thumbnail_id"], name: "index_spree_products_on_thumbnail_id"
    t.index ["total_image_count"], name: "index_spree_products_on_total_image_count"
    t.index ["variant_count"], name: "index_spree_products_on_variant_count"
  end

  create_table "spree_products_stores", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "product_id"
    t.decimal "revenue", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "store_id"
    t.integer "units_sold_count", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["product_id", "store_id"], name: "index_spree_products_stores_on_product_id_and_store_id", unique: true
    t.index ["product_id"], name: "index_spree_products_stores_on_product_id"
    t.index ["store_id", "revenue"], name: "index_products_stores_on_store_and_revenue"
    t.index ["store_id", "units_sold_count"], name: "index_products_stores_on_store_and_units_sold"
    t.index ["store_id"], name: "index_spree_products_stores_on_store_id"
  end

  create_table "spree_products_taxons", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "position"
    t.bigint "product_id"
    t.bigint "taxon_id"
    t.datetime "updated_at", precision: nil
    t.index ["position"], name: "index_spree_products_taxons_on_position"
    t.index ["product_id", "taxon_id"], name: "index_spree_products_taxons_on_product_id_and_taxon_id", unique: true
    t.index ["product_id"], name: "index_spree_products_taxons_on_product_id"
    t.index ["taxon_id"], name: "index_spree_products_taxons_on_taxon_id"
  end

  create_table "spree_promotion_action_line_items", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "promotion_action_id"
    t.integer "quantity", default: 1
    t.datetime "updated_at", precision: nil
    t.bigint "variant_id"
    t.index ["promotion_action_id", "variant_id"], name: "idx_on_promotion_action_id_variant_id_90d181a88a", unique: true
    t.index ["promotion_action_id"], name: "index_spree_promotion_action_line_items_on_promotion_action_id"
    t.index ["variant_id"], name: "index_spree_promotion_action_line_items_on_variant_id"
  end

  create_table "spree_promotion_actions", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.integer "position"
    t.bigint "promotion_id"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.index ["deleted_at"], name: "index_spree_promotion_actions_on_deleted_at"
    t.index ["id", "type"], name: "index_spree_promotion_actions_on_id_and_type"
    t.index ["promotion_id"], name: "index_spree_promotion_actions_on_promotion_id"
  end

  create_table "spree_promotion_categories", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "spree_promotion_rule_taxons", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "promotion_rule_id"
    t.bigint "taxon_id"
    t.datetime "updated_at", precision: nil
    t.index ["promotion_rule_id"], name: "index_spree_promotion_rule_taxons_on_promotion_rule_id"
    t.index ["taxon_id", "promotion_rule_id"], name: "idx_on_taxon_id_promotion_rule_id_3c91a6f5d7", unique: true
    t.index ["taxon_id"], name: "index_spree_promotion_rule_taxons_on_taxon_id"
  end

  create_table "spree_promotion_rule_users", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "promotion_rule_id"
    t.datetime "updated_at", precision: nil
    t.bigint "user_id"
    t.index ["promotion_rule_id"], name: "index_promotion_rules_users_on_promotion_rule_id"
    t.index ["user_id", "promotion_rule_id"], name: "idx_on_user_id_promotion_rule_id_ad0307a89b", unique: true
    t.index ["user_id", "promotion_rule_id"], name: "index_promotion_rules_users_on_user_id_and_promotion_rule_id"
  end

  create_table "spree_promotion_rules", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.text "preferences"
    t.bigint "product_group_id"
    t.bigint "promotion_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["product_group_id"], name: "index_promotion_rules_on_product_group_id"
    t.index ["promotion_id"], name: "index_spree_promotion_rules_on_promotion_id"
    t.index ["user_id"], name: "index_promotion_rules_on_user_id"
  end

  create_table "spree_promotions", force: :cascade do |t|
    t.boolean "advertise", default: false
    t.string "code"
    t.string "code_prefix"
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "expires_at", precision: nil
    t.integer "kind", default: 0
    t.string "match_policy", default: "all"
    t.boolean "multi_codes", default: false
    t.string "name"
    t.integer "number_of_codes"
    t.string "path"
    t.jsonb "private_metadata"
    t.bigint "promotion_category_id"
    t.jsonb "public_metadata"
    t.datetime "starts_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.integer "usage_limit"
    t.index ["advertise"], name: "index_spree_promotions_on_advertise"
    t.index ["code"], name: "index_spree_promotions_on_code"
    t.index ["expires_at"], name: "index_spree_promotions_on_expires_at"
    t.index ["id", "type"], name: "index_spree_promotions_on_id_and_type"
    t.index ["kind"], name: "index_spree_promotions_on_kind"
    t.index ["path"], name: "index_spree_promotions_on_path"
    t.index ["promotion_category_id"], name: "index_spree_promotions_on_promotion_category_id"
    t.index ["starts_at"], name: "index_spree_promotions_on_starts_at"
  end

  create_table "spree_promotions_stores", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "promotion_id"
    t.bigint "store_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["promotion_id", "store_id"], name: "index_spree_promotions_stores_on_promotion_id_and_store_id", unique: true
    t.index ["promotion_id"], name: "index_spree_promotions_stores_on_promotion_id"
    t.index ["store_id"], name: "index_spree_promotions_stores_on_store_id"
  end

  create_table "spree_properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_on", default: "both"
    t.string "filter_param"
    t.boolean "filterable", default: false, null: false
    t.integer "kind", default: 0
    t.string "name"
    t.integer "position", default: 0
    t.string "presentation", null: false
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
    t.index ["filter_param"], name: "index_spree_properties_on_filter_param"
    t.index ["filterable"], name: "index_spree_properties_on_filterable"
    t.index ["name"], name: "index_spree_properties_on_name", unique: true
    t.index ["position"], name: "index_spree_properties_on_position"
  end

  create_table "spree_property_prototypes", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "property_id"
    t.bigint "prototype_id"
    t.datetime "updated_at", precision: nil
    t.index ["property_id"], name: "index_spree_property_prototypes_on_property_id"
    t.index ["prototype_id", "property_id"], name: "index_property_prototypes_on_prototype_id_and_property_id", unique: true
    t.index ["prototype_id"], name: "index_spree_property_prototypes_on_prototype_id"
  end

  create_table "spree_property_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "presentation"
    t.bigint "spree_property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_spree_property_translations_on_locale"
    t.index ["spree_property_id", "locale"], name: "unique_property_id_per_locale", unique: true
  end

  create_table "spree_prototype_taxons", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "prototype_id"
    t.bigint "taxon_id"
    t.datetime "updated_at", precision: nil
    t.index ["prototype_id", "taxon_id"], name: "index_spree_prototype_taxons_on_prototype_id_and_taxon_id"
    t.index ["prototype_id"], name: "index_spree_prototype_taxons_on_prototype_id"
    t.index ["taxon_id"], name: "index_spree_prototype_taxons_on_taxon_id"
  end

  create_table "spree_prototypes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "updated_at", null: false
  end

  create_table "spree_refund_reasons", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.boolean "mutable", default: true
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spree_refund_reasons_on_name", unique: true
  end

  create_table "spree_refunds", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "payment_id"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "refund_reason_id"
    t.bigint "refunder_id"
    t.bigint "reimbursement_id"
    t.string "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_spree_refunds_on_payment_id"
    t.index ["refund_reason_id"], name: "index_refunds_on_refund_reason_id"
    t.index ["refunder_id"], name: "index_spree_refunds_on_refunder_id"
    t.index ["reimbursement_id"], name: "index_spree_refunds_on_reimbursement_id"
  end

  create_table "spree_reimbursement_credits", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", precision: nil
    t.bigint "creditable_id"
    t.string "creditable_type"
    t.bigint "reimbursement_id"
    t.datetime "updated_at", precision: nil
    t.index ["creditable_id", "creditable_type"], name: "index_reimbursement_credits_on_creditable_id_and_type"
    t.index ["reimbursement_id"], name: "index_spree_reimbursement_credits_on_reimbursement_id"
  end

  create_table "spree_reimbursement_types", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.boolean "mutable", default: true
    t.string "name"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spree_reimbursement_types_on_name", unique: true
    t.index ["type"], name: "index_spree_reimbursement_types_on_type"
  end

  create_table "spree_reimbursements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_return_id"
    t.string "number"
    t.bigint "order_id"
    t.bigint "performed_by_id"
    t.string "reimbursement_status"
    t.decimal "total", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["customer_return_id"], name: "index_spree_reimbursements_on_customer_return_id"
    t.index ["number"], name: "index_spree_reimbursements_on_number", unique: true
    t.index ["order_id"], name: "index_spree_reimbursements_on_order_id"
    t.index ["performed_by_id"], name: "index_spree_reimbursements_on_performed_by_id"
  end

  create_table "spree_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency"
    t.datetime "date_from", precision: nil
    t.datetime "date_to", precision: nil
    t.bigint "store_id", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["store_id"], name: "index_spree_reports_on_store_id"
    t.index ["user_id"], name: "index_spree_reports_on_user_id"
  end

  create_table "spree_return_authorization_reasons", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.boolean "mutable", default: true
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spree_return_authorization_reasons_on_name", unique: true
  end

  create_table "spree_return_authorizations", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "memo"
    t.string "number"
    t.bigint "order_id"
    t.bigint "return_authorization_reason_id"
    t.string "state"
    t.bigint "stock_location_id"
    t.datetime "updated_at", precision: nil
    t.index ["number"], name: "index_spree_return_authorizations_on_number", unique: true
    t.index ["order_id"], name: "index_spree_return_authorizations_on_order_id"
    t.index ["return_authorization_reason_id"], name: "index_return_authorizations_on_return_authorization_reason_id"
    t.index ["stock_location_id"], name: "index_spree_return_authorizations_on_stock_location_id"
  end

  create_table "spree_return_items", force: :cascade do |t|
    t.string "acceptance_status"
    t.text "acceptance_status_errors"
    t.decimal "additional_tax_total", precision: 12, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_return_id"
    t.bigint "exchange_variant_id"
    t.decimal "included_tax_total", precision: 12, scale: 4, default: "0.0", null: false
    t.bigint "inventory_unit_id"
    t.bigint "override_reimbursement_type_id"
    t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
    t.bigint "preferred_reimbursement_type_id"
    t.string "reception_status"
    t.bigint "reimbursement_id"
    t.boolean "resellable", default: true, null: false
    t.bigint "return_authorization_id"
    t.datetime "updated_at", null: false
    t.index ["customer_return_id"], name: "index_return_items_on_customer_return_id"
    t.index ["exchange_variant_id"], name: "index_spree_return_items_on_exchange_variant_id"
    t.index ["inventory_unit_id"], name: "index_spree_return_items_on_inventory_unit_id"
    t.index ["override_reimbursement_type_id"], name: "index_spree_return_items_on_override_reimbursement_type_id"
    t.index ["preferred_reimbursement_type_id"], name: "index_spree_return_items_on_preferred_reimbursement_type_id"
    t.index ["reimbursement_id"], name: "index_spree_return_items_on_reimbursement_id"
    t.index ["return_authorization_id"], name: "index_spree_return_items_on_return_authorization_id"
  end

  create_table "spree_role_users", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "invitation_id"
    t.bigint "resource_id"
    t.string "resource_type"
    t.bigint "role_id"
    t.datetime "updated_at", precision: nil
    t.bigint "user_id"
    t.string "user_type", null: false
    t.index ["invitation_id"], name: "index_spree_role_users_on_invitation_id"
    t.index ["resource_id", "resource_type", "user_id", "user_type", "role_id"], name: "idx_on_resource_id_resource_type_user_id_user_type__5600304ec6", unique: true
    t.index ["resource_type", "resource_id"], name: "index_spree_role_users_on_resource"
    t.index ["role_id"], name: "index_spree_role_users_on_role_id"
    t.index ["user_id"], name: "index_spree_role_users_on_user_id"
    t.index ["user_type"], name: "index_spree_role_users_on_user_type"
  end

  create_table "spree_roles", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.index ["name"], name: "index_spree_roles_on_name", unique: true
  end

  create_table "spree_shipments", force: :cascade do |t|
    t.decimal "additional_tax_total", precision: 10, scale: 2, default: "0.0"
    t.bigint "address_id"
    t.decimal "adjustment_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "cost", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.decimal "included_tax_total", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "non_taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "number"
    t.bigint "order_id"
    t.decimal "pre_tax_amount", precision: 12, scale: 4, default: "0.0", null: false
    t.jsonb "private_metadata"
    t.decimal "promo_total", precision: 10, scale: 2, default: "0.0"
    t.jsonb "public_metadata"
    t.datetime "shipped_at", precision: nil
    t.string "state"
    t.bigint "stock_location_id"
    t.decimal "taxable_adjustment_total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "tracking"
    t.datetime "updated_at", null: false
    t.index ["address_id"], name: "index_spree_shipments_on_address_id"
    t.index ["number"], name: "index_spree_shipments_on_number", unique: true
    t.index ["order_id"], name: "index_spree_shipments_on_order_id"
    t.index ["stock_location_id"], name: "index_spree_shipments_on_stock_location_id"
  end

  create_table "spree_shipping_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spree_shipping_categories_on_name"
  end

  create_table "spree_shipping_method_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "shipping_category_id", null: false
    t.bigint "shipping_method_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shipping_category_id", "shipping_method_id"], name: "unique_spree_shipping_method_categories", unique: true
    t.index ["shipping_category_id"], name: "index_spree_shipping_method_categories_on_shipping_category_id"
    t.index ["shipping_method_id"], name: "index_spree_shipping_method_categories_on_shipping_method_id"
  end

  create_table "spree_shipping_method_zones", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "shipping_method_id"
    t.datetime "updated_at", precision: nil
    t.bigint "zone_id"
    t.index ["shipping_method_id"], name: "index_spree_shipping_method_zones_on_shipping_method_id"
    t.index ["zone_id"], name: "index_spree_shipping_method_zones_on_zone_id"
  end

  create_table "spree_shipping_methods", force: :cascade do |t|
    t.string "admin_name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "display_on"
    t.integer "estimated_transit_business_days_max"
    t.integer "estimated_transit_business_days_min"
    t.string "name"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "tax_category_id"
    t.string "tracking_url"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_shipping_methods_on_deleted_at"
    t.index ["tax_category_id"], name: "index_spree_shipping_methods_on_tax_category_id"
  end

  create_table "spree_shipping_rates", force: :cascade do |t|
    t.decimal "cost", precision: 8, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.boolean "selected", default: false
    t.bigint "shipment_id"
    t.bigint "shipping_method_id"
    t.bigint "tax_rate_id"
    t.datetime "updated_at", null: false
    t.index ["selected"], name: "index_spree_shipping_rates_on_selected"
    t.index ["shipment_id", "shipping_method_id"], name: "spree_shipping_rates_join_index", unique: true
    t.index ["shipment_id"], name: "index_spree_shipping_rates_on_shipment_id"
    t.index ["shipping_method_id"], name: "index_spree_shipping_rates_on_shipping_method_id"
    t.index ["tax_rate_id"], name: "index_spree_shipping_rates_on_tax_rate_id"
  end

  create_table "spree_state_changes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "next_state"
    t.string "previous_state"
    t.bigint "stateful_id"
    t.string "stateful_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["stateful_id", "stateful_type"], name: "index_spree_state_changes_on_stateful_id_and_stateful_type"
  end

  create_table "spree_states", force: :cascade do |t|
    t.string "abbr"
    t.bigint "country_id"
    t.datetime "created_at", precision: nil
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.index ["country_id"], name: "index_spree_states_on_country_id"
  end

  create_table "spree_stock_items", force: :cascade do |t|
    t.boolean "backorderable", default: false
    t.integer "count_on_hand", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "stock_location_id"
    t.datetime "updated_at", null: false
    t.bigint "variant_id"
    t.index ["backorderable"], name: "index_spree_stock_items_on_backorderable"
    t.index ["deleted_at"], name: "index_spree_stock_items_on_deleted_at"
    t.index ["stock_location_id", "variant_id", "deleted_at"], name: "stock_item_by_loc_var_id_deleted_at", unique: true
    t.index ["stock_location_id", "variant_id"], name: "stock_item_by_loc_and_var_id"
    t.index ["stock_location_id"], name: "index_spree_stock_items_on_stock_location_id"
    t.index ["variant_id", "stock_location_id"], name: "index_spree_stock_items_unique_without_deleted_at", unique: true, where: "(deleted_at IS NULL)"
    t.index ["variant_id"], name: "index_spree_stock_items_on_variant_id"
  end

  create_table "spree_stock_locations", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "address1"
    t.string "address2"
    t.string "admin_name"
    t.boolean "backorderable_default", default: false
    t.string "city"
    t.string "company"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.datetime "deleted_at", precision: nil
    t.string "name"
    t.string "phone"
    t.boolean "propagate_all_variants", default: false
    t.bigint "state_id"
    t.string "state_name"
    t.datetime "updated_at", null: false
    t.string "zipcode"
    t.index ["active"], name: "index_spree_stock_locations_on_active"
    t.index ["backorderable_default"], name: "index_spree_stock_locations_on_backorderable_default"
    t.index ["country_id"], name: "index_spree_stock_locations_on_country_id"
    t.index ["deleted_at"], name: "index_spree_stock_locations_on_deleted_at"
    t.index ["propagate_all_variants"], name: "index_spree_stock_locations_on_propagate_all_variants"
    t.index ["state_id"], name: "index_spree_stock_locations_on_state_id"
  end

  create_table "spree_stock_movements", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.bigint "originator_id"
    t.string "originator_type"
    t.integer "quantity", default: 0
    t.bigint "stock_item_id"
    t.datetime "updated_at", null: false
    t.index ["originator_id", "originator_type"], name: "index_stock_movements_on_originator_id_and_originator_type"
    t.index ["stock_item_id"], name: "index_spree_stock_movements_on_stock_item_id"
  end

  create_table "spree_stock_transfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "destination_location_id"
    t.string "number"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.string "reference"
    t.bigint "source_location_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["destination_location_id"], name: "index_spree_stock_transfers_on_destination_location_id"
    t.index ["number"], name: "index_spree_stock_transfers_on_number", unique: true
    t.index ["source_location_id"], name: "index_spree_stock_transfers_on_source_location_id"
  end

  create_table "spree_store_credit_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "spree_store_credit_events", force: :cascade do |t|
    t.string "action", null: false
    t.decimal "amount", precision: 8, scale: 2
    t.string "authorization_code", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "originator_id"
    t.string "originator_type"
    t.bigint "store_credit_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "user_total_amount", precision: 8, scale: 2, default: "0.0", null: false
    t.index ["originator_id", "originator_type"], name: "spree_store_credit_events_originator"
    t.index ["store_credit_id"], name: "index_spree_store_credit_events_on_store_credit_id"
  end

  create_table "spree_store_credit_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "priority"
    t.datetime "updated_at", null: false
    t.index ["priority"], name: "index_spree_store_credit_types_on_priority"
  end

  create_table "spree_store_credits", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount_authorized", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount_used", precision: 8, scale: 2, default: "0.0", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency"
    t.datetime "deleted_at", precision: nil
    t.text "memo"
    t.bigint "originator_id"
    t.string "originator_type"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "store_id"
    t.bigint "type_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["deleted_at"], name: "index_spree_store_credits_on_deleted_at"
    t.index ["originator_id", "originator_type"], name: "spree_store_credits_originator"
    t.index ["store_id"], name: "index_spree_store_credits_on_store_id"
    t.index ["type_id"], name: "index_spree_store_credits_on_type_id"
    t.index ["user_id"], name: "index_spree_store_credits_on_user_id"
  end

  create_table "spree_store_translations", force: :cascade do |t|
    t.text "address"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "customer_support_email"
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "facebook"
    t.string "instagram"
    t.string "locale", null: false
    t.text "meta_description"
    t.text "meta_keywords"
    t.string "name"
    t.string "new_order_notifications_email"
    t.string "seo_title"
    t.bigint "spree_store_id", null: false
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_store_translations_on_deleted_at"
    t.index ["locale"], name: "index_spree_store_translations_on_locale"
    t.index ["spree_store_id", "locale"], name: "index_spree_store_translations_on_spree_store_id_locale", unique: true
  end

  create_table "spree_stores", force: :cascade do |t|
    t.text "address"
    t.bigint "checkout_zone_id"
    t.string "code"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "customer_support_email"
    t.boolean "default", default: false, null: false
    t.bigint "default_country_id"
    t.string "default_currency"
    t.string "default_locale"
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.string "facebook"
    t.string "instagram"
    t.string "mail_from_address"
    t.text "meta_description"
    t.text "meta_keywords"
    t.string "name"
    t.string "new_order_notifications_email"
    t.text "preferences"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.string "seo_robots"
    t.string "seo_title"
    t.jsonb "settings"
    t.text "storefront_custom_code_body_end"
    t.text "storefront_custom_code_body_start"
    t.text "storefront_custom_code_head"
    t.string "supported_currencies"
    t.string "supported_locales"
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["code"], name: "index_spree_stores_on_code", unique: true
    t.index ["default"], name: "index_spree_stores_on_default"
    t.index ["deleted_at"], name: "index_spree_stores_on_deleted_at"
    t.index ["url"], name: "index_spree_stores_on_url"
  end

  create_table "spree_stripe_payment_intents", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "client_secret", null: false
    t.datetime "created_at", null: false
    t.string "customer_id"
    t.string "ephemeral_key_secret"
    t.bigint "order_id", null: false
    t.bigint "payment_method_id", null: false
    t.string "stripe_id", null: false
    t.string "stripe_payment_method_id"
    t.datetime "updated_at", null: false
    t.index ["order_id", "stripe_id"], name: "index_spree_stripe_payment_intents_on_order_id_and_stripe_id", unique: true
    t.index ["order_id"], name: "index_spree_stripe_payment_intents_on_order_id"
    t.index ["payment_method_id"], name: "index_spree_stripe_payment_intents_on_payment_method_id"
  end

  create_table "spree_stripe_payment_methods_webhook_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_key_id", null: false
    t.index ["payment_method_id", "webhook_key_id"], name: "index_payment_method_id_webhook_key_id_uniqueness", unique: true
    t.index ["payment_method_id"], name: "index_payment_methods_webhook_keys_on_payment_method_id"
    t.index ["webhook_key_id"], name: "index_payment_methods_webhook_keys_on_webhook_key_id"
  end

  create_table "spree_stripe_webhook_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "signing_secret", null: false
    t.string "stripe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["signing_secret"], name: "index_spree_stripe_webhook_keys_on_signing_secret", unique: true
    t.index ["stripe_id"], name: "index_spree_stripe_webhook_keys_on_stripe_id", unique: true
  end

  create_table "spree_taggings", force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.bigint "tag_id"
    t.bigint "taggable_id"
    t.string "taggable_type"
    t.bigint "tagger_id"
    t.string "tagger_type"
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_spree_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "spree_taggings_idx", unique: true
    t.index ["tag_id"], name: "index_spree_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "spree_taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "spree_taggings_idy"
    t.index ["taggable_id"], name: "index_spree_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_spree_taggings_on_taggable_type_and_taggable_id"
    t.index ["taggable_type"], name: "index_spree_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_spree_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_spree_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_spree_taggings_on_tagger_type_and_tagger_id"
    t.index ["tenant"], name: "index_spree_taggings_on_tenant"
  end

  create_table "spree_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "taggings_count", default: 0
    t.datetime "updated_at", null: false
    t.index "lower((name)::text) varchar_pattern_ops", name: "index_spree_tags_on_lower_name"
    t.index ["name"], name: "index_spree_tags_on_name", unique: true
  end

  create_table "spree_tax_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "description"
    t.boolean "is_default", default: false
    t.string "name"
    t.string "tax_code"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_spree_tax_categories_on_deleted_at"
    t.index ["is_default"], name: "index_spree_tax_categories_on_is_default"
  end

  create_table "spree_tax_rates", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 5
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.boolean "included_in_price", default: false
    t.string "name"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.boolean "show_rate_in_label", default: true
    t.bigint "tax_category_id"
    t.datetime "updated_at", null: false
    t.bigint "zone_id"
    t.index ["deleted_at"], name: "index_spree_tax_rates_on_deleted_at"
    t.index ["included_in_price"], name: "index_spree_tax_rates_on_included_in_price"
    t.index ["show_rate_in_label"], name: "index_spree_tax_rates_on_show_rate_in_label"
    t.index ["tax_category_id"], name: "index_spree_tax_rates_on_tax_category_id"
    t.index ["zone_id"], name: "index_spree_tax_rates_on_zone_id"
  end

  create_table "spree_taxon_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "match_policy", default: "is_equal_to", null: false
    t.bigint "taxon_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["taxon_id"], name: "index_spree_taxon_rules_on_taxon_id"
  end

  create_table "spree_taxon_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "locale", null: false
    t.string "meta_description"
    t.string "meta_keywords"
    t.string "meta_title"
    t.string "name"
    t.string "permalink"
    t.string "pretty_name"
    t.bigint "spree_taxon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_spree_taxon_translations_on_locale"
    t.index ["pretty_name"], name: "index_spree_taxon_translations_on_pretty_name"
    t.index ["spree_taxon_id", "locale"], name: "index_spree_taxon_translations_on_spree_taxon_id_and_locale", unique: true
  end

  create_table "spree_taxonomies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "store_id"
    t.datetime "updated_at", null: false
    t.index ["name", "store_id"], name: "index_spree_taxonomies_on_name_and_store_id", unique: true
    t.index ["position"], name: "index_spree_taxonomies_on_position"
    t.index ["store_id"], name: "index_spree_taxonomies_on_store_id"
  end

  create_table "spree_taxonomy_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "name"
    t.bigint "spree_taxonomy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_spree_taxonomy_translations_on_locale"
    t.index ["spree_taxonomy_id", "locale"], name: "index_spree_taxonomy_translations_on_spree_taxonomy_id_locale", unique: true
  end

  create_table "spree_taxons", force: :cascade do |t|
    t.boolean "automatic", default: false, null: false
    t.integer "children_count", default: 0, null: false
    t.integer "classification_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "depth"
    t.text "description"
    t.boolean "hide_from_nav", default: false
    t.bigint "lft"
    t.string "meta_description"
    t.string "meta_keywords"
    t.string "meta_title"
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "permalink"
    t.integer "position", default: 0
    t.string "pretty_name"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.bigint "rgt"
    t.string "rules_match_policy", default: "all", null: false
    t.string "sort_order", default: "manual", null: false
    t.bigint "taxonomy_id"
    t.datetime "updated_at", null: false
    t.index ["children_count"], name: "index_spree_taxons_on_children_count"
    t.index ["classification_count"], name: "index_spree_taxons_on_classification_count"
    t.index ["lft"], name: "index_spree_taxons_on_lft"
    t.index ["name", "parent_id", "taxonomy_id"], name: "index_spree_taxons_on_name_and_parent_id_and_taxonomy_id", unique: true
    t.index ["name"], name: "index_spree_taxons_on_name"
    t.index ["parent_id"], name: "index_taxons_on_parent_id"
    t.index ["permalink", "parent_id", "taxonomy_id"], name: "index_spree_taxons_on_permalink_and_parent_id_and_taxonomy_id", unique: true
    t.index ["permalink"], name: "index_taxons_on_permalink"
    t.index ["position"], name: "index_spree_taxons_on_position"
    t.index ["pretty_name"], name: "index_spree_taxons_on_pretty_name"
    t.index ["rgt"], name: "index_spree_taxons_on_rgt"
    t.index ["taxonomy_id"], name: "index_taxons_on_taxonomy_id"
  end

  create_table "spree_trackers", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "analytics_id"
    t.datetime "created_at", null: false
    t.integer "engine", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_spree_trackers_on_active"
  end

  create_table "spree_user_identities", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.json "info"
    t.string "provider", null: false
    t.string "refresh_token"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "user_type", null: false
    t.index ["provider", "uid", "user_type"], name: "index_spree_user_identities_on_provider_uid_user_type", unique: true
    t.index ["user_type", "user_id"], name: "index_spree_user_identities_on_user"
  end

  create_table "spree_users", force: :cascade do |t|
    t.boolean "accepts_email_marketing", default: false, null: false
    t.string "authentication_token"
    t.bigint "bill_address_id"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", limit: 128
    t.integer "failed_attempts", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "last_request_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.string "login"
    t.string "password_salt", limit: 128
    t.string "perishable_token"
    t.string "persistence_token"
    t.string "phone"
    t.jsonb "private_metadata"
    t.jsonb "public_metadata"
    t.datetime "remember_created_at", precision: nil
    t.string "remember_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.string "selected_locale"
    t.bigint "ship_address_id"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["accepts_email_marketing"], name: "index_spree_users_on_accepts_email_marketing"
    t.index ["bill_address_id"], name: "index_spree_users_on_bill_address_id"
    t.index ["ship_address_id"], name: "index_spree_users_on_ship_address_id"
  end

  create_table "spree_variants", force: :cascade do |t|
    t.string "barcode"
    t.string "cost_currency"
    t.decimal "cost_price", precision: 10, scale: 2
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.decimal "depth", precision: 8, scale: 2
    t.string "dimensions_unit"
    t.datetime "discontinue_on", precision: nil
    t.decimal "height", precision: 8, scale: 2
    t.integer "image_count", default: 0, null: false
    t.boolean "is_master", default: false
    t.integer "position"
    t.jsonb "private_metadata"
    t.bigint "product_id"
    t.jsonb "public_metadata"
    t.string "sku", default: "", null: false
    t.bigint "tax_category_id"
    t.bigint "thumbnail_id"
    t.boolean "track_inventory", default: true
    t.datetime "updated_at", precision: nil, null: false
    t.decimal "weight", precision: 8, scale: 2, default: "0.0"
    t.string "weight_unit"
    t.decimal "width", precision: 8, scale: 2
    t.index ["barcode"], name: "index_spree_variants_on_barcode"
    t.index ["deleted_at"], name: "index_spree_variants_on_deleted_at"
    t.index ["discontinue_on"], name: "index_spree_variants_on_discontinue_on"
    t.index ["image_count"], name: "index_spree_variants_on_image_count"
    t.index ["is_master"], name: "index_spree_variants_on_is_master"
    t.index ["position"], name: "index_spree_variants_on_position"
    t.index ["product_id"], name: "index_spree_variants_on_product_id"
    t.index ["sku"], name: "index_spree_variants_on_sku"
    t.index ["tax_category_id"], name: "index_spree_variants_on_tax_category_id"
    t.index ["thumbnail_id"], name: "index_spree_variants_on_thumbnail_id"
    t.index ["track_inventory"], name: "index_spree_variants_on_track_inventory"
  end

  create_table "spree_webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "error_type"
    t.string "event_name", null: false
    t.integer "execution_time"
    t.jsonb "payload", null: false
    t.text "request_errors"
    t.text "response_body"
    t.integer "response_code"
    t.boolean "success"
    t.datetime "updated_at", null: false
    t.bigint "webhook_endpoint_id", null: false
    t.index ["delivered_at"], name: "index_spree_webhook_deliveries_on_delivered_at"
    t.index ["event_name"], name: "index_spree_webhook_deliveries_on_event_name"
    t.index ["response_code"], name: "index_spree_webhook_deliveries_on_response_code"
    t.index ["success"], name: "index_spree_webhook_deliveries_on_success"
    t.index ["webhook_endpoint_id"], name: "index_spree_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "spree_webhook_endpoints", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "secret_key", null: false
    t.bigint "store_id", null: false
    t.jsonb "subscriptions", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["active"], name: "index_spree_webhook_endpoints_on_active"
    t.index ["deleted_at"], name: "index_spree_webhook_endpoints_on_deleted_at"
    t.index ["store_id"], name: "index_spree_webhook_endpoints_on_store_id"
  end

  create_table "spree_wished_items", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "variant_id"
    t.bigint "wishlist_id"
    t.index ["variant_id", "wishlist_id"], name: "index_spree_wished_items_on_variant_id_and_wishlist_id", unique: true
    t.index ["variant_id"], name: "index_spree_wished_items_on_variant_id"
    t.index ["wishlist_id"], name: "index_spree_wished_items_on_wishlist_id"
  end

  create_table "spree_wishlists", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.boolean "is_default", default: false, null: false
    t.boolean "is_private", default: true, null: false
    t.string "name"
    t.bigint "store_id"
    t.string "token", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["store_id"], name: "index_spree_wishlists_on_store_id"
    t.index ["token"], name: "index_spree_wishlists_on_token", unique: true
    t.index ["user_id", "is_default"], name: "index_spree_wishlists_on_user_id_and_is_default"
    t.index ["user_id"], name: "index_spree_wishlists_on_user_id"
  end

  create_table "spree_zone_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id"
    t.bigint "zoneable_id"
    t.string "zoneable_type"
    t.index ["zone_id"], name: "index_spree_zone_members_on_zone_id"
    t.index ["zoneable_id", "zoneable_type"], name: "index_spree_zone_members_on_zoneable_id_and_zoneable_type"
  end

  create_table "spree_zones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_tax", default: false
    t.string "description"
    t.string "kind", default: "state"
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "zone_members_count", default: 0
    t.index ["default_tax"], name: "index_spree_zones_on_default_tax"
    t.index ["kind"], name: "index_spree_zones_on_kind"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "spree_option_type_translations", "spree_option_types"
  add_foreign_key "spree_option_value_translations", "spree_option_values"
  add_foreign_key "spree_payment_sources", "spree_payment_methods", column: "payment_method_id"
  add_foreign_key "spree_payment_sources", "spree_users", column: "user_id"
  add_foreign_key "spree_product_property_translations", "spree_product_properties"
  add_foreign_key "spree_product_translations", "spree_products"
  add_foreign_key "spree_property_translations", "spree_properties"
  add_foreign_key "spree_store_translations", "spree_stores"
  add_foreign_key "spree_taxon_translations", "spree_taxons"
  add_foreign_key "spree_taxonomy_translations", "spree_taxonomies"
end
