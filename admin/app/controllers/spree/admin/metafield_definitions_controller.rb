module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      private

      def model_class
        Spree::MetafieldDefinition
      end

      def permitted_resource_params
        params.require(:metafield_definition).permit(Spree::PermittedAttributes.metafield_definition_attributes)
      end

      def location_after_save
        collection_url
      end
    end
  end
end
