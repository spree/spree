module Spree
  module Admin
    class IntegrationsController < ResourceController
      prepend_before_action :prevent_from_creating_more_integrations, only: %i[new create]
      prepend_before_action :require_integration_type, only: %i[new create]

      before_action :check_if_can_connect, only: %i[create update]

      private

      def build_resource
        @object = params[:integration].delete(:type).constantize.new if params[:integration].present?
      end

      def require_integration_type
        redirect_to spree.admin_integrations_path unless params.dig(:integration, :type).present?
      end

      def prevent_from_creating_more_integrations
        type = params.dig(:integration, :type)
        redirect_to(spree.admin_integrations_path) if type.blank? || type.constantize.for_store(current_store).exists?
      end

      def check_if_can_connect
        @integration.attributes = permitted_resource_params

        unless @integration.can_connect?
          @integration.errors.add(:base, :unable_to_connect)
          render :new, status: :unprocessable_entity
        end
      end
    end
  end
end
