module Spree
  module PermittedAttributes
    ATTRIBUTES = [
      :address_attributes,
      :checkout_attributes,
      :customer_return_attributes,
      :image_attributes,
      :inventory_unit_attributes,
      :line_item_attributes,
      :option_type_attributes,
      :option_value_attributes,
      :payment_attributes,
      :product_attributes,
      :product_properties_attributes,
      :property_attributes,
      :return_authorization_attributes,
      :shipment_attributes,
      :source_attributes,
      :stock_item_attributes,
      :stock_location_attributes,
      :stock_movement_attributes,
      :store_attributes,
      :taxon_attributes,
      :taxonomy_attributes,
      :user_attributes,
      :variant_attributes
    ].freeze

    mattr_reader *ATTRIBUTES

    @@address_attributes = [
      :id, :firstname, :lastname, :first_name, :last_name,
      :address1, :address2, :city, :country_id, :state_id,
      :zipcode, :phone, :state_name, :alternative_phone, :company,
      country: [:iso, :name, :iso3, :iso_name],
      state: [:name, :abbr]
    ].freeze

    @@checkout_attributes = [
      :coupon_code, :email, :shipping_method_id, :special_instructions, :use_billing
    ].freeze

    @@customer_return_attributes = [
      :stock_location_id,
      return_items_attributes: [
        :id,
        :inventory_unit_id,
        :return_authorization_id,
        :returned,
        :pre_tax_amount,
        :acceptance_status,
        :exchange_variant_id
      ]
    ].freeze

    @@image_attributes = [:alt, :attachment, :position, :viewable_type, :viewable_id].freeze

    @@inventory_unit_attributes = [:shipment, :variant_id].freeze

    @@line_item_attributes = [:id, :variant_id, :quantity].freeze

    @@option_type_attributes = [:name, :presentation, :option_values_attributes].freeze

    @@option_value_attributes = [:name, :presentation].freeze

    @@payment_attributes = [:amount, :payment_method_id, :payment_method].freeze

    @@product_properties_attributes = [:property_name, :value, :position].freeze

    @@product_attributes = [
      :name, :description, :available_on, :permalink, :meta_description,
      :meta_keywords, :price, :sku, :deleted_at, :prototype_id,
      :option_values_hash, :weight, :height, :width, :depth,
      :shipping_category_id, :tax_category_id,
      :taxon_ids, :cost_currency, :cost_price,
      option_type_ids: []
    ].freeze

    @@property_attributes = [:name, :presentation].freeze

    @@return_authorization_attributes = [
      :amount, :memo, :stock_location_id, :inventory_units_attributes,
      :return_authorization_reason_id
    ].freeze

    @@shipment_attributes = [
      :order, :special_instructions, :stock_location_id, :id,
      :tracking, :address, :inventory_units, :selected_shipping_rate_id
    ].freeze

    # month / year may be provided by some sources, or others may elect to use one field
    @@source_attributes = [
      :number, :month, :year, :expiry, :verification_value,
      :first_name, :last_name, :cc_type, :gateway_customer_profile_id,
      :gateway_payment_profile_id, :last_digits, :name, :encrypted_data
    ].freeze

    @@stock_item_attributes = [:variant, :stock_location, :backorderable, :variant_id].freeze

    @@stock_location_attributes = [
      :name, :active, :address1, :address2, :city, :zipcode,
      :backorderable_default, :state_name, :state_id, :country_id, :phone,
      :propagate_all_variants
    ].freeze

    @@stock_movement_attributes = [
      :quantity, :stock_item, :stock_item_id, :originator, :action
    ].freeze

    @@store_attributes = [
      :name, :url, :seo_title, :meta_keywords,
      :meta_description, :default_currency, :mail_from_address
    ].freeze

    @@taxonomy_attributes = [:name]

    @@taxon_attributes = [
      :name, :parent_id, :position, :icon, :description, :permalink, :taxonomy_id,
      :meta_description, :meta_keywords, :meta_title, :child_index
    ].freeze

    # TODO Should probably use something like Spree.user_class.attributes
    @@user_attributes = [:email, :password, :password_confirmation].freeze

    @@variant_attributes = [
      :name, :presentation, :cost_price, :lock_version,
      :position, :track_inventory,
      :product_id, :product, :option_values_attributes, :price,
      :weight, :height, :width, :depth, :sku, :cost_currency,
      options: [:name, :value], option_value_ids: []
    ].freeze
  end
end
