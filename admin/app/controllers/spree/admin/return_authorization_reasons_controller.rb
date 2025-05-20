module Spree
  module Admin
    class ReturnAuthorizationReasonsController < ResourceController
      add_breadcrumb Spree.t(:return_authorization_reasons), :admin_return_authorization_reasons_path

      private

      def permitted_resource_params
        params.require(:return_authorization_reason).permit(permitted_return_authorization_reason_attributes)
      end
    end
  end
end
