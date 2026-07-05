# Permission set for managing roles and permissions.
#
# This permission set provides access to manage roles and user assignments.
# Note: The admin role cannot be modified.
#
# @example
#   Spree.permissions.assign(:admin, Spree::PermissionSets::RoleManagement)
#
module Spree
  module PermissionSets
    class RoleManagement < Base
      def activate!
        can :manage, Spree::Role
        can :manage, Spree::RoleUser

        # Protect the admin role from modification
        cannot [:update, :destroy], Spree::Role, name: ['admin']
      end
    end
  end
end
