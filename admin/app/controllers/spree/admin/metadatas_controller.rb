module Spree
  module Admin
    class MetadatasController < Spree::Admin::BaseController
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit]

      def edit; end

      def update
        if @resource.update(private_metadata: metadata_params(:private), public_metadata: metadata_params(:public))
          flash[:success] = flash_message_for(@resource, :successfully_updated)
          redirect_to spree.edit_admin_metadata_path(
            @resource,
            resource_type: @resource.class.to_s
          )
        else
          flash.now[:error] = @resource.errors.full_messages.join(', ')
          render :edit
        end
      end

      private

      def metadata_params(type)
        metadata_params = params.permit("#{type}_metadata" => {}).permit!.to_h
        metadata_params["#{type}_metadata"]&.each_with_object({}) do |(_i, m), o|
          if m[:value].present?
            o[m[:key]] = m[:value]
          end
        end || {}
      end

      def public_metadata
        params.permit(:public_metadata).permit!
      end

      def resource_class
        valid_resource_types = Spree.base_class.descendants.map(&:to_s)

        unless valid_resource_types.include?(params[:resource_type])
          raise ActiveRecord::RecordNotFound
        end

        @resource_class ||= params[:resource_type].constantize
      end

      def set_resource
        @resource = if resource_class.respond_to?(:friendly)
                      resource_class.friendly.find(params[:id])
                    else
                      resource_class.find(params[:id])
                    end
      end

      def load_data
        @resource_name =
          @resource.try(:presentation).presence ||
          @resource.try(:number).presence ||
          @resource.try(:name).presence ||
          @resource.class.model_name.human
      end
    end
  end
end
