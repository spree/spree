module Spree
  module Admin
    class MetafieldsController < BaseController
      before_action :load_owner

      def edit
        @metafields = @owner.metafields
        @metafield_definitions = Spree::MetafieldDefinition.where(owner_type: @owner.class.name)
      end

      def update
        if @owner.update(permitted_metafields_params)
          flash[:success] = flash_message_for(@owner, :successfully_updated)
        else
          flash[:error] = @owner.errors.full_messages.to_sentence
        end

        redirect_to spree.edit_admin_metafields_path(@owner)
      end

      private

      def permitted_metafields_params
        params.require(owner_type.param_key).permit(metafields_attributes: [:id, :value, :_destroy])
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
