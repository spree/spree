module Spree
  module Core
    module ControllerHelpers
      module StrongParameters
        def permitted_order_attributes
          [:line_items_attributes, :coupon_code]
        end

        def permitted_address_attributes
           [:firstname, :lastname, :address1, :address2,
            :city, :country_id, :state_id, :zipcode, :phone,
            :state_name, :alternative_phone, :company]
        end

        def permitted_source_attributes
          [:number, :month, :year, :verification_value,
           :first_name, :last_name]
        end

        def permitted_payment_attributes
          [:payment_method_id, :source_attributes => permitted_source_attributes]
        end

        def permitted_checkout_attributes
          [:email, :use_billing, :shipping_method_id, :coupon_code,
           :bill_address_attributes => permitted_address_attributes,
           :ship_address_attributes => permitted_address_attributes,
           :payments_attributes => permitted_payment_attributes]
        end

        def permitted_image_attributes
          [:alt, :attachment, :position, :viewable_type, :viewable_id]
        end

        def permitted_inventory_unit_attributes
          [:shipment, :variant_id]
        end

        def permitted_option_type_attributes
          [:name, :presentation, :option_values_attributes]
        end

        def permitted_option_value_attributes
          [:name, :presentation]
        end

        def permitted_payment_attributes
          [:amount, :payment_method_id, :source_attributes]
        end

        def permitted_product_properties_attributes
          [:property_name, :value, :position]
        end

        def permitted_product_attributes
          [:name, :description, :available_on, :permalink, :meta_description,
           :meta_keywords, :price, :sku, :deleted_at, :prototype_id,
           :option_values_hash, :weight, :height, :width, :depth,
           :shipping_category_id, :tax_category_id, :product_properties_attributes,
           :variants_attributes, :taxon_ids, :option_type_ids, :cost_currency, :cost_price]
        end

        def permitted_property_attributes
          [:name, :presentation]
        end

        def permitted_return_authorization_attributes
          [:amount, :reason, :stock_location_id]
        end

        def permitted_shipment_attributes
          [:order, :special_instructions, :stock_location_id,
           :tracking, :address, :inventory_units, :selected_shipping_rate_id]
        end

        def permitted_stock_item_attributes
          [:variant, :stock_location, :backorderable, :variant_id]
        end

        def permitted_stock_location_attributes
          [:name, :active, :address1, :address2, :city, :zipcode,
           :backorderable_default, :state_name, :state_id, :country_id, :phone,
           :propagate_all_variants]
        end

        def permitted_stock_movement_attributes
          [:quantity, :stock_item, :stock_item_id, :originator, :action]
        end

        def permitted_taxonomy_attributes
          [:name]
        end

        def permitted_taxon_attributes
          [:name, :parent_id, :position, :icon, :description, :permalink, :taxonomy_id,
           :meta_description, :meta_keywords, :meta_title]
        end

        # TODO Should probably use something like Spree.user_class.permitted_attributes
        def permitted_user_attributes
          [:email, :password, :password_confirmation]
        end

        def permitted_variant_attributes
          [:name, :presentation, :cost_price, :lock_version,
           :position, :option_value_ids,
           :product_id, :option_values_attributes, :price,
           :weight, :height, :width, :depth, :sku, :cost_currency]
        end
      end
    end
  end
end
