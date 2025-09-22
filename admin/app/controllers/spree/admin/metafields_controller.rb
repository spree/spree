module Spree
  module Admin
    class MetafieldsController < BaseController
      before_action :load_owner

      # GET /admin/<resource_name_plural>/<id>/edit
      def edit
        @metafields = @owner.metafields
        @metafield_definitions = Spree::MetafieldDefinition.where(owner_type: @owner.class.name)

        @metafield_definitions.each do |metafield_definition|
          @owner.metafields.build(metafield_definition: metafield_definition) unless @owner.has_metafield?(metafield_definition)
        end
      end

      # PUT /admin/<resource_name_plural>/<id>
      def update
        if @owner.update(permitted_metafields_params)
          flash.now[:success] = flash_message_for(@owner, :successfully_updated)
        else
          flash.now[:error] = @owner.errors.full_messages.to_sentence
        end
      end

      private

      def permitted_metafields_params
        params.require(owner_type.model_name.param_key).permit(metafields_attributes: permitted_metafield_attributes)
      end

      # eg. Spree::Product
      def owner_type
        @owner_type ||= allowed_owner_types.find { |type| type.name == params[:owner_type] }
      end

      def load_owner
        raise ActiveRecord::RecordNotFound if params[:owner_type].blank?
        raise ActiveRecord::RecordNotFound if owner_type.blank?

        @owner = if owner_type.respond_to?(:friendly)
                   owner_type.friendly.find(params[:id])
                 else
                   owner_type.find(params[:id])
                 end
      end

      def allowed_owner_types
        @allowed_owner_types ||= Rails.application.config.spree.metafield_enabled_resources
      end
    end
  end
end
