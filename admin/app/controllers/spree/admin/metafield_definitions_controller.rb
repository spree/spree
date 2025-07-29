module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      private

      def model_class
        Spree::MetafieldDefinition
      end

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        params[:q][:s] ||= 'name asc'

        @search = super.ransack(params[:q])
        @collection = @search.result(distinct: true)

        @collection
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
