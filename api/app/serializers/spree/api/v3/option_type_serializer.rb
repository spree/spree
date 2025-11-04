module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
            presentation: resource.presentation,
            position: resource.position
          }

          # Conditionally include option_values
          base_attrs[:option_values] = serialize_option_values if include?('option_values')

          base_attrs
        end

        private

        def serialize_option_values
          resource.option_values.map do |option_value|
            option_value_serializer.new(option_value, nested_context('option_values')).as_json
          end
        end

        # Serializer dependencies
        def option_value_serializer
          Spree::Api::Dependencies.v3_storefront_option_value_serializer.constantize
        end
      end
    end
  end
end
