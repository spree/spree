module Spree
  module Admin
    class IntegrationsController < ResourceController
      include Spree::Admin::PreferencesConcern

      prepend_before_action :require_integration_type, only: %i[new create]
      prepend_before_action :prevent_from_creating_more_integrations, only: %i[new create]

      before_action -> { clear_empty_password_preferences(:integration) }, only: :update

      before_action :check_if_can_connect, only: %i[create update]

      add_breadcrumb Spree.t(:integrations), :admin_integrations_path
      add_breadcrumb_icon 'plug-connected'

      private

      def allowed_integration_types
        @allowed_integration_types ||= Spree.integrations.map { |klass| [klass.to_s, klass] }.to_h
      end

      def require_integration_type
        redirect_to spree.admin_integrations_path unless params.dig(:integration, :type).present?
      end

      def prevent_from_creating_more_integrations
        type = params.dig(:integration, :type)

        if allowed_integration_types.key?(type) && allowed_integration_types[type].for_store(current_store).exists?
          redirect_to spree.admin_integrations_path
        end
      end

      def build_resource
        return unless params[:integration].present?

        type = params[:integration].delete(:type)

        if allowed_integration_types.key?(type)
          @object = allowed_integration_types[type].new
        else
          flash[:error] = Spree.t('admin.integrations.invalid_integration_type')
          redirect_to spree.admin_integrations_path
        end
      end

      def check_if_can_connect
        @integration.attributes = permitted_resource_params

        unless @integration.can_connect?
          @integration.errors.add(:base, :unable_to_connect, error_message: @integration.connection_error_message)
          render action == :create ? :new : :edit, status: :unprocessable_entity
        end
      end

      def permitted_resource_params
        params.require(:integration).permit(*permitted_integration_attributes + @object.preferences.keys.map { |key| "preferred_#{key}" })
      end
    end
  end
end
