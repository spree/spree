module Spree
  module CSV
    module CustomFieldsHelper
      private

      def custom_field_definitions_for_csv(resource)
        Spree::CustomFieldDefinition.for_resource_type(resource.class.to_s).order(:namespace, :key)
      end

      def custom_fields_for_csv(resource)
        Spree::CustomFieldDefinition.for_resource_type(resource.class.to_s).order(:namespace, :key).map do |mf_def|
          resource.custom_fields.find { |mf| mf.custom_field_definition_id == mf_def.id }&.csv_value
        end
      end
    end
  end
end
