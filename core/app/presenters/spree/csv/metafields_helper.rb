module Spree
  module CSV
    module MetafieldsHelper
      private

      def metafield_definitions_for_csv(resource)
        Spree::MetafieldDefinition.for_resource_type(resource.class.to_s).order(:namespace, :key)
      end

      def metafields_for_csv(resource)
        Spree::MetafieldDefinition.for_resource_type(resource.class.to_s).order(:namespace, :key).map do |mf_def|
          resource.metafields.find { |mf| mf.metafield_definition_id == mf_def.id }&.csv_value
        end
      end
    end
  end
end
