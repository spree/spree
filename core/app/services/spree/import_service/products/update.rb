module Spree
  module ImportService
    module Products
      class Update
        def initialize(row:)
          @row = row
        end

        def call
          update_variant
          update_product

          refresh_properties
          refresh_option_types
        end

        private

        attr_reader :row

        delegate :product, to: :variant
        delegate :id, to: :product, prefix: true

        def variant
          @variant ||= Spree::Variant.find_by!(sku: row[:sku])
        end

        def update_variant
          Spree::ImportService::Products::Serializers::VariantAttributesSerializer.new(row: row, product_id: product_id).to_h.tap do |attr|
            variant.update!(attr)
          end
        end

        def update_product
          Spree::ImportService::Products::Serializers::ProductAttributesSerializer.new(row: row).to_h.tap do |attr|
            product.update!(attr)
          end
        end

        def refresh_properties
          product.product_properties.delete_all
          Spree::ImportService::Products::Serializers::PropertiesAttributesSerializer.new(row: row, product_id: product_id).to_a.tap do |attr|
            Spree::ProductProperty.insert_all(attr)
          end
        end

        def refresh_option_types
          variant.option_value_variants.delete_all
          product.product_option_types.delete_all
          
          Spree::ImportService::Products::Serializers::OptionTypesAttributesSerializer.new(row: row, product_id: product_id).to_a.tap do |attr|
            Spree::ProductOptionType.insert_all(attr)
          end

          Spree::ImportService::Products::Serializers::OptionValuesAttributesSerializer.new(row: row, variant_id: variant.id).to_a.tap do |attr|
            Spree::OptionValueVariant.insert_all(attr)
          end
        end
      end
    end
  end
end