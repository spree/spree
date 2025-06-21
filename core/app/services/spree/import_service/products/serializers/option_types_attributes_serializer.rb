module Spree
  module ImportService
    module Products
      module Serializers
        class OptionTypesAttributesSerializer
          # supports format: option1_name, option1_value, option2_name...
          OPTION_TYPE_PREFIX = "option"
          OPTION_TYPE_NAME_SUFFIX = "_name"

          def initialize(row:, product_id:)
            @row = row.symbolize_keys!
            @product_id = product_id
          end

          def to_a
            @to_a ||= sorted_option_types.map.with_index do |name, index|
              {
                option_type_id: option_type_name_id_mapper.fetch(name),
                position: index,
                product_id: product_id
              }
            end
          rescue KeyError => error
            raise Spree::ImportService::Error.new(identifier: row[:sku], message: "Option type #{error.key} not found" )
          end

          private

          attr_reader :row, :product_id

          def sorted_option_types
            @sorted_option_types ||= row
              .stringify_keys
              .select { |key, _value| key.starts_with?(OPTION_TYPE_PREFIX) && key.ends_with?(OPTION_TYPE_NAME_SUFFIX) }
              .sort_by { |k, _v| k.delete_prefix(OPTION_TYPE_PREFIX).delete_suffix(OPTION_TYPE_NAME_SUFFIX).to_i } # ensure proper order of properties
              .map(&:last)
          end

          def option_type_name_id_mapper
            @option_type_name_id_mapper ||= Spree::OptionType.where(name: sorted_option_types).pluck(:name, :id).to_h
          end
        end
      end
    end
  end
end