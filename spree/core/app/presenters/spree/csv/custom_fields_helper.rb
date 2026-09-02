module Spree
  module CSV
    module CustomFieldsHelper
      private

      # The store the export runs for decides the schema. Its header row comes
      # from the same store's definitions, so reading any other store's here
      # would shift every value column.
      def custom_field_definitions_for_csv(resource, store)
        store.custom_field_definitions.for_resource_type(resource.class.to_s).order(:namespace, :key)
      end

      def custom_fields_for_csv(resource, store)
        custom_field_definitions_for_csv(resource, store).map do |definition|
          resource.custom_fields.find { |custom_field| custom_field.custom_field_definition_id == definition.id }&.csv_value
        end
      end
    end
  end
end
