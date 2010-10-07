class SpreeZeroNineZero < ActiveRecord::Migration
  # This is a legacy migration consolidating all of the database changes needed as of Spree 0.9.0
  # (See http://railsdog.lighthouseapp.com/projects/31096-spree/tickets/772)

  def self.up
    create_table "addresses", :force => true do |t|
      t.string   "firstname"
      t.string   "lastname"
      t.string   "address1"
      t.string   "address2"
      t.string   "city"
      t.integer  "state_id"
      t.string   "zipcode"
      t.integer  "country_id"
      t.string   "phone"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "state_name"
      t.string   "alternative_phone"
    end

    create_table "adjustments", :force => true do |t|
      t.integer  "order_id"
      t.string   "type"
      t.decimal  "amount",                 :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string   "description"
      t.integer  "position"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "adjustment_source_id"
      t.string   "adjustment_source_type"
      t.string   "secondary_type"
    end

    create_table "assets", :force => true do |t|
      t.integer  "viewable_id"
      t.string   "viewable_type", :limit => 50
      t.string   "attachment_content_type"
      t.string   "attachment_file_name"
      t.integer  "attachment_size"
      t.integer  "position"
      t.string   "type", :limit => 75
      t.datetime "attachment_updated_at"
      t.integer  "attachment_width"
      t.integer  "attachment_height"
    end

    create_table "calculators", :force => true do |t|
      t.string   "type"
      t.integer  "calculable_id",   :null => false
      t.string   "calculable_type", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "checkouts", :force => true do |t|
      t.integer  "order_id"
      t.string   "email"
      t.string   "ip_address"
      t.text     "special_instructions"
      t.integer  "bill_address_id"
      t.datetime "completed_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "configurations", :force => true do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "type", :limit => 50
    end

    add_index "configurations", ["name", "type"], :name => "index_configurations_on_name_and_type"

    create_table "countries", :force => true do |t|
      t.string  "iso_name"
      t.string  "iso"
      t.string  "name"
      t.string  "iso3"
      t.integer "numcode"
    end

    create_table "coupons", :force => true do |t|
      t.string   "code"
      t.string   "description"
      t.integer  "usage_limit"
      t.boolean  "combine"
      t.datetime "expires_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "starts_at"
    end

    create_table "creditcard_txns", :force => true do |t|
      t.integer  "creditcard_payment_id"
      t.decimal  "amount",                :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.integer  "txn_type"
      t.string   "response_code"
      t.text     "avs_response"
      t.text     "cvv_response"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "creditcards", :force => true do |t|
      t.text     "number"
      t.string   "month"
      t.string   "year"
      t.text     "verification_value"
      t.string   "cc_type"
      t.string   "display_number"
      t.string   "first_name"
      t.string   "last_name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "start_month"
      t.string   "start_year"
      t.string   "issue_number"
      t.integer  "address_id"
      t.integer  "checkout_id"
    end

    create_table "gateway_configurations", :force => true do |t|
      t.integer  "gateway_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateway_option_values", :force => true do |t|
      t.integer  "gateway_configuration_id"
      t.integer  "gateway_option_id"
      t.text     "value"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateway_options", :force => true do |t|
      t.string   "name"
      t.text     "description"
      t.integer  "gateway_id"
      t.boolean  "textarea",    :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "gateways", :force => true do |t|
      t.string   "clazz"
      t.string   "name"
      t.text     "description"
      t.boolean  "active"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "inventory_units", :force => true do |t|
      t.integer  "variant_id"
      t.integer  "order_id"
      t.string   "state"
      t.integer  "lock_version", :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "line_items", :force => true do |t|
      t.integer  "order_id"
      t.integer  "variant_id"
      t.integer  "quantity",                                 :null => false
      t.decimal  "price",      :precision => 8, :scale => 2, :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "line_items", ["order_id"], :name => "index_line_items_on_order_id"
    add_index "line_items", ["variant_id"], :name => "index_line_items_on_variant_id"

    create_table "option_types", :force => true do |t|
      t.string   "name",         :limit => 100
      t.string   "presentation", :limit => 100
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "option_types_prototypes", :id => false, :force => true do |t|
      t.integer "prototype_id"
      t.integer "option_type_id"
    end

    create_table "option_values", :force => true do |t|
      t.integer  "option_type_id"
      t.string   "name"
      t.integer  "position"
      t.string   "presentation"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "option_values_variants", :id => false, :force => true do |t|
      t.integer "variant_id"
      t.integer "option_value_id"
    end

    add_index "option_values_variants", ["variant_id"], :name => "index_option_values_variants_on_variant_id"

    create_table "orders", :force => true do |t|
      t.integer  "user_id"
      t.string   "number",           :limit => 15
      t.decimal  "item_total",                     :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal  "total",                          :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "state"
      t.string   "token"
      t.decimal  "adjustment_total",               :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal  "credit_total",                   :precision => 8, :scale => 2, :default => 0.0, :null => false
    end

    add_index "orders", ["number"], :name => "index_orders_on_number"

    create_table "payments", :force => true do |t|
      t.integer  "order_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.decimal  "amount",        :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.integer  "creditcard_id"
      t.string   "type"
    end

    create_table "preferences", :force => true do |t|
      t.string   "attribute",  :null => false, :limit => 100
      t.integer  "owner_id",   :null => false, :limit => 30
      t.string   "owner_type", :null => false, :limit => 50
      t.integer  "group_id"
      t.string   "group_type", :limit => 50
      t.string   "value"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "preferences", ["owner_id", "owner_type", "attribute", "group_id", "group_type"], :name => "index_preferences_on_owner_and_attribute_and_preference", :unique => true

    create_table "product_option_types", :force => true do |t|
      t.integer  "product_id"
      t.integer  "option_type_id"
      t.integer  "position"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "product_properties", :force => true do |t|
      t.integer  "product_id"
      t.integer  "property_id"
      t.string   "value"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "products", :force => true do |t|
      t.string   "name",                 :default => "", :null => false
      t.text     "description"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "permalink"
      t.datetime "available_on"
      t.integer  "tax_category_id"
      t.integer  "shipping_category_id"
      t.datetime "deleted_at"
      t.string   "meta_description"
      t.string   "meta_keywords"
    end

    add_index "products", ["available_on"], :name => "index_products_on_available_on"
    add_index "products", ["deleted_at"], :name => "index_products_on_deleted_at"
    add_index "products", ["name"], :name => "index_products_on_name"
    add_index "products", ["permalink"], :name => "index_products_on_permalink"

    create_table "products_taxons", :id => false, :force => true do |t|
      t.integer "product_id"
      t.integer "taxon_id"
    end

    add_index "products_taxons", ["product_id"], :name => "index_products_taxons_on_product_id"
    add_index "products_taxons", ["taxon_id"], :name => "index_products_taxons_on_taxon_id"

    create_table "properties", :force => true do |t|
      t.string   "name"
      t.string   "presentation", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "properties_prototypes", :id => false, :force => true do |t|
      t.integer "prototype_id"
      t.integer "property_id"
    end

    create_table "prototypes", :force => true do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "roles", :force => true do |t|
      t.string "name"
    end

    create_table "roles_users", :id => false, :force => true do |t|
      t.integer "role_id"
      t.integer "user_id"
    end

    add_index "roles_users", ["role_id"], :name => "index_roles_users_on_role_id"
    add_index "roles_users", ["user_id"], :name => "index_roles_users_on_user_id"

    create_table "shipments", :force => true do |t|
      t.integer  "order_id"
      t.integer  "shipping_method_id"
      t.string   "tracking"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "number"
      t.decimal  "cost",               :precision => 8, :scale => 2
      t.datetime "shipped_at"
      t.integer  "address_id"
    end

    create_table "shipping_categories", :force => true do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "shipping_methods", :force => true do |t|
      t.integer  "zone_id"
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "state_events", :force => true do |t|
      t.integer  "order_id"
      t.integer  "user_id"
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "previous_state"
    end

    create_table "states", :force => true do |t|
      t.string  "name"
      t.string  "abbr"
      t.integer "country_id"
    end

    create_table "tax_categories", :force => true do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "tax_rates", :force => true do |t|
      t.integer  "zone_id"
      t.decimal  "amount",          :precision => 8, :scale => 4
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "tax_category_id"
    end

    create_table "taxonomies", :force => true do |t|
      t.string   "name",       :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "taxons", :force => true do |t|
      t.integer  "taxonomy_id",                :null => false
      t.integer  "parent_id"
      t.integer  "position",    :default => 0
      t.string   "name",                       :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "permalink"
    end

    create_table "users", :force => true do |t|
      t.string   "email"
      t.string   "crypted_password",          :limit => 128, :default => "", :null => false
      t.string   "salt",                      :limit => 128, :default => "", :null => false
      t.string   "remember_token"
      t.string   "remember_token_expires_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "persistence_token"
      t.string   "single_access_token"
      t.string   "perishable_token"
      t.integer  "login_count",                              :default => 0,  :null => false
      t.integer  "failed_login_count",                       :default => 0,  :null => false
      t.datetime "last_request_at"
      t.datetime "current_login_at"
      t.datetime "last_login_at"
      t.string   "current_login_ip"
      t.string   "last_login_ip"
      t.string   "login"
      t.integer  "ship_address_id"
      t.integer  "bill_address_id"
    end

    create_table "variants", :force => true do |t|
      t.integer  "product_id"
      t.string   "sku",                                      :default => "",    :null => false
      t.decimal  "price",      :precision => 8, :scale => 2,                    :null => false
      t.decimal  "weight",     :precision => 8, :scale => 2
      t.decimal  "height",     :precision => 8, :scale => 2
      t.decimal  "width",      :precision => 8, :scale => 2
      t.decimal  "depth",      :precision => 8, :scale => 2
      t.datetime "deleted_at"
      t.boolean  "is_master",                                :default => false
    end

    add_index "variants", ["product_id"], :name => "index_variants_on_product_id"

    create_table "zone_members", :force => true do |t|
      t.integer  "zone_id"
      t.integer  "zoneable_id"
      t.string   "zoneable_type"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "zones", :force => true do |t|
      t.string   "name"
      t.string   "description"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end

  def self.down
    # No going back
  end
end
