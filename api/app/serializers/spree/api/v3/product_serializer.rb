module Spree
  module Api
    module V3
      class ProductSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
            description: resource.description,
            slug: resource.slug,
            sku: resource.sku,
            barcode: resource.barcode,
            available_on: timestamp(resource.available_on),
            meta_description: resource.meta_description,
            meta_keywords: resource.meta_keywords,
            purchasable: resource.purchasable?,
            in_stock: resource.in_stock?,
            backorderable: resource.backorderable?,
            available: resource.available?,
            currency: currency,
            price: price_value,
            display_price: display_price_value,
            compare_at_price: compare_at_price_value,
            display_compare_at_price: display_compare_at_price_value,
            tags: resource.taggings.map(&:tag),
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include associations based on include parameter
          base_attrs[:images] = serialize_images if include?('images')
          base_attrs[:variants] = serialize_variants if include?('variants')
          base_attrs[:default_variant] = serialize_default_variant if include?('default_variant')
          base_attrs[:master_variant] = serialize_master_variant if include?('master_variant')
          base_attrs[:option_types] = serialize_option_types if include?('option_types')
          base_attrs[:taxons] = serialize_taxons if include?('taxons')

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
          resource.variant_images.map do |image|
            image_serializer.new(image, nested_context('images')).as_json
          end
        end

        def serialize_variants
          resource.variants.map do |variant|
            variant_serializer.new(variant, nested_context('variants')).as_json
          end
        end

        def serialize_default_variant
          variant_serializer.new(resource.default_variant, nested_context('default_variant')).as_json if resource.default_variant
        end

        def serialize_master_variant
          variant_serializer.new(resource.master, nested_context('master_variant')).as_json if resource.master
        end

        def serialize_option_types
          resource.option_types.map do |option_type|
            option_type_serializer.new(option_type, nested_context('option_types')).as_json
          end
        end

        def serialize_taxons
          resource.taxons_for_store(store).map do |taxon|
            taxon_serializer.new(taxon, nested_context('taxons')).as_json
          end
        end

        # Serializer dependencies
        def image_serializer
          Spree::Api::Dependencies.v3_storefront_image_serializer.constantize
        end

        def variant_serializer
          Spree::Api::Dependencies.v3_storefront_variant_serializer.constantize
        end

        def option_type_serializer
          Spree::Api::Dependencies.v3_storefront_option_type_serializer.constantize
        end

        def taxon_serializer
          Spree::Api::Dependencies.v3_storefront_taxon_serializer.constantize
        end
      end
    end
  end
end
