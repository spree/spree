module Spree
  module Admin
    class RolesController < ResourceController
      add_breadcrumb Spree.t(:users), :admin_admin_users_path
      add_breadcrumb Spree.t(:roles), :admin_roles_path

      private

      def permitted_resource_params
        params.require(:role).permit(permitted_role_attributes)
      end
    end
  end
end
