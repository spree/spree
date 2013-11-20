module Spree
  module Api
    module ApiHelpers
      ATTRIBUTES = [
        :product_attributes,
        :product_property_attributes,
        :variant_attributes,
        :image_attributes,
        :option_value_attributes,
        :order_attributes,
        :line_item_attributes,
        :option_type_attributes,
        :payment_attributes,
        :payment_method_attributes,
        :shipment_attributes,
        :taxonomy_attributes,
        :taxon_attributes,
        :inventory_unit_attributes,
        :return_authorization_attributes,
        :address_attributes,
        :country_attributes,
        :state_attributes,
        :adjustment_attributes,
        :inventory_unit_attributes,
        :return_authorization_attributes,
        :creditcard_attributes,
        :user_attributes,
        :property_attributes,
        :stock_location_attributes,
        :stock_movement_attributes,
        :stock_item_attributes
      ]

      mattr_reader *ATTRIBUTES

      def required_fields_for(model)
        required_fields = model._validators.select do |field, validations|
          validations.any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
        end.map(&:first) # get fields that are invalid
        # Permalinks presence is validated, but are really automatically generated
        # Therefore we shouldn't tell API clients that they MUST send one through
        required_fields.map!(&:to_s).delete("permalink")
        required_fields
      end

      @@product_attributes = [
        :id, :name, :description, :price, :display_price, :available_on,
        :permalink, :meta_description, :meta_keywords, :shipping_category_id,
        :taxon_ids
      ]

      @@product_property_attributes = [
        :id, :product_id, :property_id, :value, :property_name
      ]

      @@variant_attributes = [
        :id, :name, :sku, :price, :weight, :height, :width, :depth, :is_master,
        :cost_price, :permalink, :description
      ]

      @@image_attributes = [
        :id, :position, :attachment_content_type, :attachment_file_name, :type,
        :attachment_updated_at, :attachment_width, :attachment_height, :alt
      ]

      @@option_value_attributes = [
        :id, :name, :presentation, :option_type_name, :option_type_id,
        :option_type_presentation
      ]

      @@order_attributes = [
        :id, :number, :item_total, :total, :ship_total, :state, :adjustment_total,
        :user_id, :created_at, :updated_at, :completed_at, :payment_total,
        :shipment_state, :payment_state, :email, :special_instructions, :channel
      ]

      @@line_item_attributes = [:id, :quantity, :price, :variant_id]

      @@option_type_attributes = [:id, :name, :presentation, :position]

      @@payment_attributes = [
        :id, :source_type, :source_id, :amount, :display_amount,
        :payment_method_id, :response_code, :state, :avs_response, :created_at,
        :updated_at
      ]

      @@payment_method_attributes = [:id, :name, :description]

      @@shipment_attributes = [:id, :tracking, :number, :cost, :shipped_at, :state]

      @@taxonomy_attributes = [:id, :name]

      @@taxon_attributes = [
        :id, :name, :pretty_name, :permalink, :parent_id,
        :taxonomy_id
      ]

      @@inventory_unit_attributes = [
        :id, :lock_version, :state, :variant_id, :shipment_id,
        :return_authorization_id
      ]

      @@return_authorization_attributes = [
        :id, :number, :state, :amount, :order_id, :reason, :created_at,
        :updated_at
      ]

      @@address_attributes = [
        :id, :firstname, :lastname, :full_name, :address1, :address2, :city,
        :zipcode, :phone, :company, :alternative_phone, :country_id, :state_id,
        :state_name
      ]

      @@country_attributes = [:id, :iso_name, :iso, :iso3, :name, :numcode]

      @@state_attributes = [:id, :name, :abbr, :country_id]

      @@adjustment_attributes = [
        :id, :source_type, :source_id, :adjustable_type, :adjustable_id,
        :originator_type, :originator_id, :amount, :label, :mandatory,
        :locked, :eligible,  :created_at, :updated_at
      ]

      @@creditcard_attributes = [
        :id, :month, :year, :cc_type, :last_digits, :first_name, :last_name,
        :gateway_customer_profile_id, :gateway_payment_profile_id
      ]

      @@user_attributes = [:id, :email, :created_at, :updated_at]

      @@property_attributes = [:id, :name, :presentation]

      @@stock_location_attributes = [
        :id, :name, :address1, :address2, :city, :state_id, :state_name,
        :country_id, :zipcode, :phone, :active
      ]

      @@stock_movement_attributes = [:id, :quantity, :stock_item_id]

      @@stock_item_attributes = [
        :id, :count_on_hand, :backorderable, :lock_version, :stock_location_id,
        :variant_id
      ]
    end
  end
end
