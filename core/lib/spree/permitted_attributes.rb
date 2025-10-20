module Spree
  module PermittedAttributes
    ATTRIBUTES = [
      :address_attributes,
      :asset_attributes,
      :checkout_attributes,
      :classification_attributes,
      :cms_page_attributes,
      :cms_section_attributes,
      :custom_domain_attributes,
      :customer_return_attributes,
      :digital_attributes,
      :digital_link_attributes,
      :export_attributes,
      :gift_card_attributes,
      :gift_card_batch_attributes,
      :image_attributes,
      :import_attributes,
      :import_mapping_attributes,
      :integration_attributes,
      :inventory_unit_attributes,
      :invitation_attributes,
      :line_item_attributes,
      :menu_attributes,
      :menu_item_attributes,
      :metafield_attributes,
      :metafield_definition_attributes,
      :option_type_attributes,
      :option_value_attributes,
      :page_attributes,
      :page_block_attributes,
      :page_link_attributes,
      :page_section_attributes,
      :payment_attributes,
      :payment_method_attributes,
      :policy_attributes,
      :post_attributes,
      :post_category_attributes,
      :product_attributes,
      :promotion_attributes,
      :promotion_rule_attributes,
      :promotion_action_attributes,
      :product_properties_attributes,
      :property_attributes,
      :refund_attributes,
      :refund_reason_attributes,
      :reimbursement_attributes,
      :reimbursement_type_attributes,
      :report_attributes,
      :return_authorization_attributes,
      :return_authorization_reason_attributes,
      :role_attributes,
      :shipment_attributes,
      :shipping_method_attributes,
      :shipping_category_attributes,
      :source_attributes,
      :stock_item_attributes,
      :stock_location_attributes,
      :stock_movement_attributes,
      :stock_transfer_attributes,
      :store_attributes,
      :store_credit_attributes,
      :store_credit_category_attributes,
      :tax_rate_attributes,
      :tax_category_attributes,
      :taxon_attributes,
      :taxonomy_attributes,
      :theme_attributes,
      :user_attributes,
      :variant_attributes,
      :wishlist_attributes,
      :wished_item_attributes,
      :zone_attributes
    ]

    mattr_reader(*ATTRIBUTES)

    @@address_attributes = [
      :id, :firstname, :lastname, :first_name, :last_name,
      :address1, :address2, :city, :country_iso, :country_id, :state_id,
      :zipcode, :phone, :state_name, :alternative_phone, :company,
      :user_id, :deleted_at, :label, :quick_checkout,
      { country: [:iso, :name, :iso3, :iso_name],
        state: [:name, :abbr] }
    ]

    @@asset_attributes = [:type, :viewable_id, :viewable_type, :attachment, :alt, :position]

    @@checkout_attributes = [
      :coupon_code, :email, :shipping_method_id, :special_instructions, :use_billing, :use_shipping,
      :user_id, :bill_address_id, :ship_address_id, :accept_marketing, :signup_for_an_account, :currency
    ]

    @@classification_attributes = [
      :position, :taxon_id, :product_id
    ]

    @@cms_page_attributes = [:title, :meta_title, :content, :meta_description, :visible, :slug, :locale]

    @@cms_section_attributes = [:name, :cms_page_id, :fit, :destination, { content: {}, settings: {} }]

    @@custom_domain_attributes = [:url, :default]

    @@customer_return_attributes = [:stock_location_id, {
      return_items_attributes: [:id, :inventory_unit_id, :return_authorization_id, :returned, :pre_tax_amount,
                                :acceptance_status, :exchange_variant_id, :resellable]
    }]

    @@digital_attributes = [:attachment, :variant_id]

    @@digital_link_attributes = [:access_counter]

    @@export_attributes = [:type, :format, :record_selection, :search_params]

    @@gift_card_attributes = [:code, :amount, :expires_at, :user_id, :currency]

    @@gift_card_batch_attributes = [:prefix, :codes_count, :amount, :expires_at, :currency]

    @@image_attributes = [:alt, :attachment, :position, :viewable_type, :viewable_id]

    @@import_attributes = [:type, :attachment, :delimiter]

    @@import_mapping_attributes = [:file_column]

    @@integration_attributes = [:type, :active]

    @@inventory_unit_attributes = [:shipment, :shipment_id, :variant_id]

    @@invitation_attributes = [:email, :expires_at, :role_id]

    @@line_item_attributes = [:id, :variant_id, :quantity]

    @@menu_attributes = [:name, :locale, :location]

    @@menu_item_attributes = [:name, :subtitle, :destination, :new_window, :item_type,
                              :linked_resource_type, :linked_resource_id, :code, :menu_id]

    @@metafield_attributes = [:id, :value, :type, :metafield_definition_id, :_destroy]

    @@metafield_definition_attributes = [:key, :name, :namespace, :metafield_type, :resource_type, :display_on]

    @@option_type_attributes = [:name, :presentation, :position, :filterable,
                                option_values_attributes: [:id, :name, :presentation, :position, :_destroy]]

    @@option_value_attributes = [:name, :presentation, :position]

    @@page_attributes = [:name, :slug, :meta_title, :meta_description, :meta_keywords]

    @@page_block_attributes = [:type, :name, :text, :position, :asset]

    @@page_link_attributes = [:linkable_id, :linkable_type, :position, :label, :url, :open_in_new_tab]

    @@page_section_attributes = [:type, :name, :position, :asset, :text, :description]

    @@payment_attributes = [:amount, :payment_method_id, :payment_method]

    @@payment_method_attributes = [:name, :type, :description, :active, :display_on, :auto_capture, :position]

    @@policy_attributes = [:name, :slug, :body]

    @@post_attributes = [:title, :meta_title, :meta_description, :slug, :author_id, :post_category_id, :published_at, :content, :excerpt, :image, tag_list: []]

    @@post_category_attributes = [:title, :slug, :description]

    @@product_properties_attributes = [:property_name, :property_id, :value, :position, :_destroy]

    @@product_attributes = [
      :name, :description, :available_on, :make_active_at, :discontinue_on, :permalink, :meta_description,
      :meta_keywords, :meta_title, :price, :sku, :deleted_at, :prototype_id,
      :option_values_hash, :weight, :height, :width, :depth,
      :shipping_category_id, :tax_category_id,
      :cost_currency, :cost_price, :compare_at_price,
      :slug, :track_inventory, :backorderable, :barcode, :status,
      :weight_unit, :dimensions_unit,
      {
        tag_list: [],
        label_list: [],
        option_type_ids: [],
        taxon_ids: [],
        store_ids: [],
        product_option_types_attributes: [:id, :option_type_id, :position, :_destroy]
      }
    ]

    @@promotion_attributes = [:name, :description, :starts_at, :expires_at, :code, :usage_limit, :path, :match_policy,
                              :advertise, :promotion_category_id, :code_prefix, :kind, :number_of_codes, :multi_codes, store_ids: []]

    @@promotion_rule_attributes = [:type, :preferred_match_policy, preferred_eligible_values: [], user_ids_to_add: [], product_ids_to_add: [], taxon_ids_to_add: []]

    @@promotion_action_attributes = [:type, :calculator_type, calculator_attributes: {}, promotion_action_line_items_attributes: [:id, :promotion_action_id, :variant_id, :quantity, :_destroy]]

    @@property_attributes = [:name, :presentation, :position, :kind, :display_on]

    @@refund_attributes = [:amount, :refund_reason_id]

    @@refund_reason_attributes = [:name, :active, :mutable]

    @@reimbursement_attributes = [return_items_attributes: [:id, :override_reimbursement_type_id, :pre_tax_amount, :exchange_variant_id]]

    @@reimbursement_type_attributes = [:name, :type, :active, :mutable]

    @@report_attributes = [:type, :date_from, :date_to, :currency]

    @@return_authorization_attributes = [
      :amount, :memo, :stock_location_id, :inventory_units_attributes,
      :return_authorization_reason_id, {
        return_items_attributes: [
          :_destroy,
          :id, :inventory_unit_id,
          :preferred_reimbursement_type_id,
          :return_authorization_id, :returned, :pre_tax_amount,
          :acceptance_status, :exchange_variant_id, :resellable
        ]
      }
    ]

    @@return_authorization_reason_attributes = [:name, :active]

    @@return_item_attributes = [:inventory_unit_id, :return_authorization_id, :returned, :pre_tax_amount, :acceptance_status, :exchange_variant_id, :resellable]

    @@role_attributes = [:name]

    @@shipment_attributes = [
      :order, :special_instructions, :stock_location_id, :id,
      :tracking, :address, :inventory_units, :selected_shipping_rate_id
    ]

    @@shipping_category_attributes = [:name]

    @@shipping_method_attributes = [:name, :admin_name, :code, :tracking_url, :tax_category_id, :display_on,
                                    :estimated_transit_business_days_min, :estimated_transit_business_days_max,
                                    :calculator_type, :preferences, zone_ids: [], shipping_category_ids: [], calculator_attributes: {}]

    # month / year may be provided by some sources, or others may elect to use one field
    @@source_attributes = [
      :id, :number, :month, :year, :expiry, :verification_value,
      :first_name, :last_name, :cc_type, :gateway_customer_profile_id,
      :gateway_payment_profile_id, :last_digits, :name, :encrypted_data
    ]

    @@stock_item_attributes = [:variant_id, :stock_location_id, :backorderable, :count_on_hand]

    @@stock_location_attributes = [
      :name, :active, :address1, :address2, :city, :zipcode, :company,
      :backorderable_default, :state_name, :state_id, :country_id, :phone,
      :propagate_all_variants
    ]

    @@stock_movement_attributes = [
      :quantity, :stock_item, :stock_item_id, :originator, :action
    ]

    @@stock_transfer_attributes = [:source_location_id, :destination_location_id, :reference,
                                   stock_movements_attributes: [:variant_id, :quantity, :originator_id, :stock_item_id]]

    @@store_attributes = [:name, :url, :seo_title, :code, :meta_keywords,
                          :meta_description, :default_currency, :mail_from_address,
                          :customer_support_email, :description, :address, :contact_phone,
                          :supported_locales, :default_locale, :default_country_id, :supported_currencies,
                          :new_order_notifications_email, :checkout_zone_id, :seo_robots,
                          :preferred_timezone, :preferred_weight_unit, :preferred_unit_system,
                          :preferred_digital_asset_authorized_clicks, :preferred_digital_asset_authorized_days,
                          :preferred_limit_digital_download_count, :preferred_limit_digital_download_days,
                          :preferred_digital_asset_link_expire_time,
                          :logo, :mailer_logo, :social_logo, :favicon_image,
                          :import_products_from_store_id, :import_payment_methods_from_store_id,
                          :checkout_message, :preferred_guest_checkout,
                          :customer_terms_of_service, :customer_privacy_policy,
                          :customer_returns_policy, :customer_shipping_policy, :default_country_iso]

    @@store_credit_attributes = %i[amount currency category_id memo]

    @@store_credit_category_attributes = [:name]

    @@taxonomy_attributes = [:name, :position]

    @@tax_category_attributes = [:name, :tax_code,:description, :is_default]

    @@tax_rate_attributes = [:name, :amount, :amount_percentage, :zone_id, :tax_category_id, :included_in_price, :show_rate_in_label, :calculator_type, calculator_attributes: {}]

    @@taxon_attributes = [
      :name, :parent_id, :position, :icon, :description, :permalink, :hide_from_nav,
      :taxonomy_id, :meta_description, :meta_keywords, :meta_title, :child_index,
      :automatic, :rules_match_policy, :sort_order,
      :image, :square_image, :description,
      taxon_rules_attributes: [:id, :type, :value, :match_policy, :_destroy],
    ]

    @@theme_attributes = [:name, :type, :default]

    @@user_attributes = [:email, :bill_address_id, :ship_address_id, :password, :first_name, :last_name,
                         :password_confirmation, :selected_locale, :avatar, :accepts_email_marketing, :phone,
                         { public_metadata: {}, private_metadata: {}, tag_list: [] }]

    @@variant_attributes = [
      :name, :presentation, :cost_price, :discontinue_on, :lock_version,
      :position, :track_inventory, :tax_category_id,
      :product_id, :product, :option_values_attributes, :price, :compare_at_price,
      :weight, :height, :width, :depth, :sku, :barcode, :cost_currency,
      :weight_unit, :dimensions_unit,
      {
        options: [:id, :name, :option_value_presentation, :option_value_name, :position, :_destroy],
        stock_items_attributes: [:id, :count_on_hand, :stock_location_id, :backorderable, :_destroy],
        prices_attributes: [:id, :amount, :compare_at_amount, :currency, :_destroy],
        price: {},
        option_value_variants_attributes: [:id, :option_value_id, :_destroy],
        option_value_ids: []
      }
    ]

    @@wishlist_attributes = [:name, :is_default, :is_private]

    @@wished_item_attributes = [:variant_id, :quantity]

    @@zone_attributes = [:name, :description, :default_tax, :kind, :states_country_id, country_ids: [], state_ids: []]
  end
end
