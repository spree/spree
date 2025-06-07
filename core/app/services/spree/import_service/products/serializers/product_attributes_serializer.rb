module Spree
  module ImportService
    module Products
      module Serializers
        class ProductAttributesSerializer
          PRODUCT_ATTRIBUTES = %i[name description available_on meta_description meta_keywords].freeze
          # price taxons option_types 

          def initialize(row:)
            @row = row.symbolize_keys!
          end

          def to_h
            @to_h ||= row.slice(*PRODUCT_ATTRIBUTES)
                        .merge!(tax_category_id: tax_category_id)
                        .merge!(shipping_category_id: shipping_category_id)
                        .merge!(available_on: available_on)
          end

          private

          attr_reader :row

          def properties_hash
            { 
              product_properties: Spree::ImportService::Products::PropertiesAttributesSerializer.new(row: row).to_a
            }
          end

          def available_on
            row[:available_on].presence&.to_datetime
          end

          def tax_category_id
            tax_category = row.fetch(:tax_category)
            Spree::TaxCategory.find_by!(name: tax_category).id
          rescue ActiveRecord::RecordNotFound => error
            raise Spree::ImportService::Error.new(identifier: row[:sku], message: "Tax Category #{tax_category} not found" )
          end

          def shipping_category_id
            shipping_category = row.fetch(:shipping_category)
            Spree::ShippingCategory.find_by!(name: shipping_category).id
          rescue ActiveRecord::RecordNotFound => error
            raise Spree::ImportService::Error.new(identifier: row[:sku], message: "Shipping Category #{shipping_category} not found" )
          end
        end
      end
    end
  end
end