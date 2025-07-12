module Spree
  module ImportService
    module Products
      module Serializers
        class VariantAttributesSerializer
          VARIANT_ATTRIBUTES = %i[sku].freeze
          NUMERIC_ATTRIBUTES = %i[cost_price weight height width depth].freeze

          def initialize(row:, product_id:)
            @row = row.symbolize_keys!
            @product_id = product_id
          end

          def to_h
            to_h ||= row.slice(*VARIANT_ATTRIBUTES).merge!(converted_attributes).merge(product_id: product_id)
          end

          private

          attr_reader :row, :product_id

          def converted_attributes
            row.slice(*NUMERIC_ATTRIBUTES).transform_values { |value| value.presence&.to_d }
          end
        end
      end
    end
  end
end
