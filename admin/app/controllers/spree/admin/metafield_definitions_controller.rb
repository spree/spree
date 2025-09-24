module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      add_breadcrumb Spree.t(:metafield_definitions), :admin_metafield_definitions_path

      new_action.before :set_resource_type_from_params

      private

      def set_resource_type_from_params
        @object.resource_type = Spree::MetafieldDefinition.available_resources.find { |type| type.name.to_s == params[:resource_type] }
      end

      def location_after_save
        collection_url
      end

      def permitted_resource_params
        params.require(:metafield_definition).permit(permitted_metafield_definition_attributes)
      end
    end
  end
end
