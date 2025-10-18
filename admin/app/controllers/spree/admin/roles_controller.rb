module Spree
  module Admin
    class RolesController < ResourceController
      include Spree::Admin::SettingsConcern

      private

      def permitted_resource_params
        params.require(:role).permit(permitted_role_attributes)
      end
    end
  end
end
