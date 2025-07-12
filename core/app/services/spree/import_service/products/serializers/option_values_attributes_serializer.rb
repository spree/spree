module Spree
  module ImportService
    module Products
      module Serializers
        class OptionValuesAttributesSerializer
          # supports format: option1_name, option1_value, option2_name...
          OPTION_VALUE_PREFIX = "option"
          OPTION_VALUE_SUFFIX = "_value"


          def initialize(row:, variant_id:)
            @row = row.symbolize_keys!
            @variant_id = variant_id
          end

          def to_a
            @to_a ||= option_values.map do |option_value|
              {
                option_value_id: option_value_name_id_mapper.fetch(option_value),
                variant_id: variant_id
              }
            end
          rescue KeyError => error
            raise Spree::ImportService::Error.new(identifier: row[:sku], message: "Option value #{error.key} not found" )
          end

          private

          attr_reader :row, :variant_id

          def option_values
            @option_values ||= row
              .stringify_keys
              .select { |key, _value| key.starts_with?(OPTION_VALUE_PREFIX) && key.ends_with?(OPTION_VALUE_SUFFIX) }
              .values
          end

          def option_value_name_id_mapper
            @option_value_name_id_mapper ||= Spree::OptionValue.where(name: option_values).pluck(:name, :id).to_h
          end
        end
      end
    end
  end
end