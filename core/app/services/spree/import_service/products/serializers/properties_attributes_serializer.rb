module Spree
  module ImportService
    module Products
      module Serializers
        class PropertiesAttributesSerializer
          # supports format: property1_name, property1_value, property2_name...
          PROPERTY_PREFIX = "property"
          PROPERTY_NAME_SUFFIX = "_name"
          PROPERTY_VALUE_SUFFIX = "_value"

          def initialize(row:, product_id:)
            @row = row.stringify_keys!
            @product_id = product_id
          end

          def to_a
            @to_a ||= sorted_property_value_hash.map.with_index do |(property_name, property_value), index|
              {
                property_id: properties_name_id_mapper.fetch(property_name),
                position: index,
                value: property_value,
                product_id: product_id
              }
            end
          rescue KeyError => error
            raise Spree::ImportService::Error.new(identifier: row['sku'], message: "Property #{error.key} not found" )
          end

          private

          attr_reader :row, :product_id

          # { sample output: { 'color' => 'red' }
          def sorted_property_value_hash
            @sorted_property_value_hash ||= sorted_properties_hash
              .map { |column_name, value| [value, row.fetch(column_name.gsub(PROPERTY_NAME_SUFFIX, PROPERTY_VALUE_SUFFIX))] }
              .to_h
          end

          def sorted_properties_hash
            row.select { |key, _value| key.starts_with?(PROPERTY_PREFIX) && key.ends_with?(PROPERTY_NAME_SUFFIX) }
              .compact_blank
              .sort_by { |k, _v| k.delete_prefix(PROPERTY_PREFIX).delete_suffix(PROPERTY_NAME_SUFFIX).to_i }
          end

          def properties_name_id_mapper
            @properties_name_id_mapper ||= Spree::Property.where(name: sorted_property_value_hash.keys).pluck(:name, :id).to_h
          end
        end
      end
    end
  end
end