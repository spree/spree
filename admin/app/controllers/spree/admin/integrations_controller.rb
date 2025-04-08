module Spree
  module Admin
    class IntegrationsController < ResourceController
      prepend_before_action :require_integration_type, only: %i[new create]
      prepend_before_action :prevent_from_creating_more_integrations, only: %i[new create]

      before_action :check_if_can_connect, only: %i[create update]

      private

      def allowed_integration_types
        Rails.application.config.spree.integrations.map(&:to_s)
      end

      def require_integration_type
        redirect_to spree.admin_integrations_path unless params.dig(:integration, :type).present?
      end

      def prevent_from_creating_more_integrations
        type = params.dig(:integration, :type)

        if type.in?(allowed_integration_types) && type.constantize.for_store(current_store).exists?
          redirect_to spree.admin_integrations_path
        end
      end

      def build_resource
        return unless params[:integration].present?

        type = params[:integration].delete(:type)

        if type.in?(allowed_integration_types)
          @object = type.constantize.new
        else
          flash[:error] = Spree.t('admin.integrations.invalid_integration_type')
          redirect_to spree.admin_integrations_path
        end
      end

      def check_if_can_connect
        @integration.attributes = permitted_resource_params

        unless @integration.can_connect?
          @integration.errors.add(:base, :unable_to_connect)
          render action == :create ? :new : :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
