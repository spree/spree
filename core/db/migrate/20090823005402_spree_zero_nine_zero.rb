class SpreeZeroNineZero < ActiveRecord::Migration
  # This is a legacy migration consolidating all of the database changes needed as of Spree 0.9.0
  # (See http://railsdog.lighthouseapp.com/projects/31096-spree/tickets/772)

  def change
    create_table :addresses, :force => true do |t|
      t.string   :firstname, :lastname, :address1, :address2, :city,
                 :zipcode, :phone, :state_name, :alternative_phone
      t.references :state
      t.references :country

      t.timestamps
    end

    create_table :adjustments, :force => true do |t|
      t.integer  :position, :adjustment_source_id
      t.decimal  :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string   :type, :description, :adjustment_source_type, :secondary_type
      t.references :order
      
      t.timestamps
    end

    create_table :assets, :force => true do |t|
      t.integer  :viewable_id, :attachment_width, :attachment_height,
                 :attachment_size, :position
      t.string   :viewable_type, :limit => 50
      t.string   :attachment_content_type, :attachment_file_name
      t.string   :type, :limit => 75
      t.datetime :attachment_updated_at
    end

    create_table :calculators, :force => true do |t|
      t.string   :type
      t.integer  :calculable_id,   :null => false
      t.string   :calculable_type, :null => false

      t.timestamps
    end

    create_table :checkouts, :force => true do |t|
      t.references :order
      t.string   :email, :ip_address
      t.text     :special_instructions
      t.integer  :bill_address_id
      t.datetime :completed_at

      t.timestamps
    end

    create_table :configurations, :force => true do |t|
      t.string   :name
      t.string   :type, :limit => 50
      
      t.timestamps
    end

    add_index :configurations, [:name, :type], :name => 'index_configurations_on_name_and_type'

    create_table :countries, :force => true do |t|
      t.string   :iso_name, :iso, :iso3, :name
      t.integer  :numcode
    end

    create_table :coupons, :force => true do |t|
      t.string   :code, :description
      t.integer  :usage_limit
      t.boolean  :combine
      t.datetime :expires_at, :starts_at
      
      t.timestamps
    end

    create_table :creditcard_txns, :force => true do |t|
      t.integer  :creditcard_payment_id, :txn_type
      t.decimal  :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string   :response_code
      t.text     :avs_response, :cvv_response

      t.timestamps
    end

    create_table :creditcards, :force => true do |t|
      t.text     :number, :verification_value
      t.string   :month, :year, :cc_type, :display_number, :first_name,
                 :last_name, :start_month, :start_year, :issue_number
      t.references :address
      t.references :checkout

      t.timestamps
    end

    create_table :gateway_configurations, :force => true do |t|
      t.references :gateway

      t.timestamps
    end

    create_table :gateway_option_values, :force => true do |t|
      t.references :gateway_configuration
      t.references :gateway_option
      t.text :value

      t.timestamps
    end

    create_table :gateway_options, :force => true do |t|
      t.string   :name
      t.text     :description
      t.boolean  :textarea, :default => false
      t.references :gateway

      t.timestamps
    end

    create_table :gateways, :force => true do |t|
      t.string   :clazz, :name
      t.text     :description
      t.boolean  :active

      t.timestamps
    end

    create_table :inventory_units, :force => true do |t|
      t.integer  :lock_version, :default => 0
      t.string   :state
      t.references :variant
      t.references :order

      t.timestamps
    end

    create_table :line_items, :force => true do |t|
      t.references :order
      t.references :variant
      t.integer  :quantity,                            :null => false
      t.decimal  :price, :precision => 8, :scale => 2, :null => false

      t.timestamps
    end

    add_index :line_items, :order_id, :name => 'index_line_items_on_order_id'
    add_index :line_items, :variant_id, :name => 'index_line_items_on_variant_id'

    create_table :option_types, :force => true do |t|
      t.string   :name,         :limit => 100
      t.string   :presentation, :limit => 100

      t.timestamps
    end

    create_table :option_types_prototypes, :id => false, :force => true do |t|
      t.references :prototype
      t.references :option_type
    end

    create_table :option_values, :force => true do |t|
      t.integer  :position
      t.string   :name, :presentation
      t.references :option_type

      t.timestamps
    end

    create_table :option_values_variants, :id => false, :force => true do |t|
      t.integer  :variant_id
      t.integer  :option_value_id
    end

    add_index :option_values_variants, :variant_id, :name => 'index_option_values_variants_on_variant_id'

    create_table :orders, :force => true do |t|
      t.string   :number,           :limit => 15
      t.decimal  :item_total,       :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal  :total,            :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string   :state
      t.string   :token
      t.decimal  :adjustment_total, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal  :credit_total,     :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.references :user

      t.timestamps
    end

    add_index :orders, :number, :name => 'index_orders_on_number'

    create_table :payments, :force => true do |t|
      t.decimal  :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string   :type
      t.references :order
      t.references :creditcard

      t.timestamps
    end

    create_table :preferences, :force => true do |t|
      t.string   :attribute,  :null => false, :limit => 100
      t.integer  :owner_id,   :null => false, :limit => 30
      t.string   :owner_type, :null => false, :limit => 50
      t.integer  :group_id
      t.string   :group_type, :limit => 50
      t.string   :value

      t.timestamps
    end

    add_index :preferences, [:owner_id, :owner_type, :attribute, :group_id, :group_type], :name => 'index_preferences_on_owner_and_attribute_and_preference', :unique => true

    create_table :product_option_types, :force => true do |t|
      t.integer  :position
      t.references :product
      t.references :option_type

      t.timestamps
    end

    create_table :product_properties, :force => true do |t|
      t.string   :value
      t.references :product
      t.references :property

      t.timestamps
    end

    create_table :products, :force => true do |t|
      t.string   :name, :default => '', :null => false
      t.text     :description
      t.datetime :available_on, :deleted_at
      t.string   :permalink, :meta_description, :meta_keywords
      t.references :tax_category
      t.references :shipping_category

      t.timestamps
    end

    add_index :products, :available_on, :name => 'index_products_on_available_on'
    add_index :products, :deleted_at, :name => 'index_products_on_deleted_at'
    add_index :products, :name, :name => 'index_products_on_name'
    add_index :products, :permalink, :name => 'index_products_on_permalink'

    create_table :products_taxons, :id => false, :force => true do |t|
      t.references :product
      t.references :taxon
    end

    add_index :products_taxons, :product_id, :name => 'index_products_taxons_on_product_id'
    add_index :products_taxons, :taxon_id, :name => 'index_products_taxons_on_taxon_id'

    create_table :properties, :force => true do |t|
      t.string   :name
      t.string   :presentation, :null => false

      t.timestamps
    end

    create_table :properties_prototypes, :id => false, :force => true do |t|
      t.references :prototype
      t.references :property
    end

    create_table :prototypes, :force => true do |t|
      t.string   :name

      t.timestamps
    end

    create_table :roles, :force => true do |t|
      t.string   :name
    end

    create_table :roles_users, :id => false, :force => true do |t|
      t.references :role
      t.references :user
    end

    add_index :roles_users, :role_id, :name => 'index_roles_users_on_role_id'
    add_index :roles_users, :user_id, :name => 'index_roles_users_on_user_id'

    create_table :shipments, :force => true do |t|
      t.string   :tracking, :number
      t.decimal  :cost, :precision => 8, :scale => 2
      t.datetime :shipped_at
      t.references :order
      t.references :shipping_method
      t.references :address

      t.timestamps
    end

    create_table :shipping_categories, :force => true do |t|
      t.string   :name

      t.timestamps
    end

    create_table :shipping_methods, :force => true do |t|
      t.string   :name
      t.references :zone

      t.timestamps
    end

    create_table :state_events, :force => true do |t|
      t.string   :name, :previous_state
      t.references :order
      t.references :user

      t.timestamps
    end

    create_table :states, :force => true do |t|
      t.string   :name
      t.string   :abbr
      t.references :country
    end

    create_table :tax_categories, :force => true do |t|
      t.string   :name, :description

      t.timestamps
    end

    create_table :tax_rates, :force => true do |t|
      t.decimal  :amount, :precision => 8, :scale => 6
      t.references :zone
      t.references :tax_category

      t.timestamps
    end

    create_table :taxonomies, :force => true do |t|
      t.string   :name, :null => false

      t.timestamps
    end

    create_table :taxons, :force => true do |t|
      t.integer  :parent_id
      t.integer  :position,    :default => 0
      t.string   :name,        :null => false
      t.string   :permalink
      t.references :taxonomy

      t.timestamps
    end

    create_table :users, :force => true do |t|
      t.string   :crypted_password, :limit => 128, :default => '', :null => false
      t.string   :salt,             :limit => 128, :default => '', :null => false
      t.string   :email, :remember_token, :remember_token_expires_at, 
                 :persistence_token, :single_access_token, :perishable_token
      t.integer  :login_count,        :default => 0, :null => false
      t.integer  :failed_login_count, :default => 0, :null => false
      t.datetime :last_request_at, :current_login_at, :last_login_at
      t.string   :current_login_ip, :last_login_ip, :login
      t.integer  :ship_address_id, :bill_address_id

      t.timestamps
    end

    create_table :variants, :force => true do |t|
      t.string   :sku,        :default => '', :null => false
      t.decimal  :price,      :precision => 8, :scale => 2,                    :null => false
      t.decimal  :weight,     :precision => 8, :scale => 2
      t.decimal  :height,     :precision => 8, :scale => 2
      t.decimal  :width,      :precision => 8, :scale => 2
      t.decimal  :depth,      :precision => 8, :scale => 2
      t.datetime :deleted_at
      t.boolean  :is_master,  :default => false
      t.references :product
    end

    add_index :variants, :product_id, :name => 'index_variants_on_product_id'

    create_table :zone_members, :force => true do |t|
      t.integer  :zoneable_id
      t.string   :zoneable_type
      t.references :zone

      t.timestamps
    end

    create_table :zones, :force => true do |t|
      t.string   :name, :description

      t.timestamps
    end
  end
end
