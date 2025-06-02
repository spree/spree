module Spree
  module ImportService
    module Products
      class Create
        def initialize(row:)
          @row = row
        end

        def call
          create_product
          built_variant = Spree::Variant.new(variant_attributes)
          Spree::ImportService::Products::Serializers::OptionValuesAttributesSerializer.new(row: row, variant_id: nil).to_a.map do |attributes|
            built_variant.option_value_variants.build.assign_attributes(attributes)
          end
          built_variant.save!
          
          create_associated_resources
        end

        private

        attr_reader :row

        delegate :id, to: :product, prefix: true

        # bypass after_initialize callback
        def create_product
          @product ||= Spree::Product.new(product_attributes).tap do |product|
            product.tax_category_id = product_attributes[:tax_category_id] || product.tax_category_id
            product.save!
          end
        end
        alias_method :product, :create_product

        def product_attributes
          Spree::ImportService::Products::Serializers::ProductAttributesSerializer.new(row: row).to_h
        end

        def variant_attributes
          Spree::ImportService::Products::Serializers::VariantAttributesSerializer.new(row: row, product_id: product_id).to_h
        end

        def create_associated_resources
          Spree::ImportService::Products::Serializers::PropertiesAttributesSerializer.new(row: row, product_id: product_id).to_a.tap do |attr|
            Spree::ProductProperty.insert_all(attr)
          end
          Spree::ImportService::Products::Serializers::OptionTypesAttributesSerializer.new(row: row, product_id: product_id).to_a.tap do |attr|
            Spree::ProductOptionType.insert_all(attr)
          end
        end
      end
    end
  end
end