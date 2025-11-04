module Spree
  module Api
    module V3
      class VariantSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
            sku: resource.sku,
            barcode: resource.barcode,
            weight: resource.weight&.to_f,
            height: resource.height&.to_f,
            width: resource.width&.to_f,
            depth: resource.depth&.to_f,
            is_master: resource.is_master,
            options_text: resource.options_text,
            purchasable: resource.purchasable?,
            in_stock: resource.in_stock?,
            backorderable: resource.backorderable?,
            currency: currency,
            price: price_value,
            display_price: display_price_value,
            compare_at_price: compare_at_price_value,
            display_compare_at_price: display_compare_at_price_value
          }

          # Conditionally include associations
          base_attrs[:images] = serialize_images if include?('images')
          base_attrs[:option_values] = serialize_option_values if include?('option_values')
          base_attrs[:product] = serialize_product if include?('product')

          base_attrs
        end

        private

        def price_value
          price = price_in_currency(resource)
          price&.amount&.to_f
        end

        def display_price_value
          price = price_in_currency(resource)
          price&.display_price&.to_s
        end

        def compare_at_price_value
          price = price_in_currency(resource)
          price&.compare_at_amount&.to_f
        end

        def display_compare_at_price_value
          price = price_in_currency(resource)
          return nil unless price&.compare_at_amount

          Spree::Money.new(price.compare_at_amount, currency: currency).to_s
        end

        def serialize_images
          resource.images.map do |image|
            image_serializer.new(image, nested_context('images')).as_json
          end
        end

        def serialize_option_values
          resource.option_values.map do |option_value|
            option_value_serializer.new(option_value, nested_context('option_values')).as_json
          end
        end

        def serialize_product
          product_serializer.new(resource.product, nested_context('product')).as_json if resource.product
        end

        # Serializer dependencies
        def image_serializer
          Spree::Api::Dependencies.v3_storefront_image_serializer.constantize
        end

        def option_value_serializer
          Spree::Api::Dependencies.v3_storefront_option_value_serializer.constantize
        end

        def product_serializer
          Spree::Api::Dependencies.v3_storefront_product_serializer.constantize
        end
      end
    end
  end
end
