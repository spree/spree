module Spree
  module Admin
    class MetafieldsController < BaseController
      before_action :load_resource

      # GET /admin/<resource_name_plural>/<id>/edit
      def edit
        @metafields = @resource.metafields
        @metafield_definitions = Spree::MetafieldDefinition.where(resource_type: @resource.class.name)

        @metafield_definitions.each do |metafield_definition|
          @resource.metafields.build(metafield_definition: metafield_definition) unless @resource.has_metafield?(metafield_definition)
        end
      end

      # PUT /admin/<resource_name_plural>/<id>
      def update
        if @resource.update(permitted_metafields_params)
          flash.now[:success] = flash_message_for(@resource, :successfully_updated)
        else
          flash.now[:error] = @resource.errors.full_messages.to_sentence
        end
      end

      private

      def permitted_metafields_params
        params.require(resource_type.model_name.param_key).permit(metafields_attributes: permitted_metafield_attributes)
      end

      # eg. Spree::Product
      def resource_type
        @resource_type ||= allowed_resource_types.find { |type| type.name == params[:resource_type] }
      end

      def load_resource
        raise ActiveRecord::RecordNotFound if params[:resource_type].blank?
        raise ActiveRecord::RecordNotFound if resource_type.blank?

        @resource = if resource_type.respond_to?(:friendly)
                   resource_type.friendly.find(params[:id])
                 else
                   resource_type.find(params[:id])
                 end
      end

      def allowed_resource_types
        @allowed_resource_types ||= Rails.application.config.spree.metafield_enabled_resources
      end
    end
  end
end
