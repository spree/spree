module Spree
  module Admin
    class RolesController < ResourceController
      add_breadcrumb Spree.t(:users), :admin_admin_users_path
      add_breadcrumb Spree.t(:roles), :admin_roles_path
    end
  end
end
