module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      add_breadcrumb Spree.t(:metafield_definitions), :admin_metafield_definitions_path

      private

      def location_after_save
        collection_url
      end

      def permitted_resource_params
        params.require(:metafield_definition).permit(permitted_metafield_definition_attributes)
      end
    end
  end
end
