# Manages the mapping between roles and permission sets.
#
# This configuration allows you to define which permission sets are assigned to each role.
# Permission sets are reusable groups of permissions that can be applied to roles.
#
# @example Assigning permission sets to a role
#   Spree.permissions.assign(:customer_service, [
#     Spree::PermissionSets::OrderDisplay,
#     Spree::PermissionSets::UserManagement
#   ])
#
# @example Clearing permission sets from a role
#   Spree.permissions.clear(:customer_service)
#
# @example Getting permission sets for a role
#   Spree.permissions.permission_sets_for(:admin)
#   # => [Spree::PermissionSets::SuperUser]
#
module Spree
  class PermissionConfiguration
    # Default role used for unauthenticated users
    DEFAULT_ROLE = :default

    # Admin role with full access
    ADMIN_ROLE = :admin

    def initialize
      @role_permissions = {}
    end

    # Assigns permission sets to a role.
    #
    # @param role_name [Symbol, String] the name of the role
    # @param permission_sets [Array<Class>, Class] permission set class(es) to assign
    # @return [Array<Class>] the assigned permission sets
    #
    # @example
    #   Spree.permissions.assign(:customer_service, Spree::PermissionSets::OrderDisplay)
    #   Spree.permissions.assign(:admin, [
    #     Spree::PermissionSets::SuperUser
    #   ])
    def assign(role_name, permission_sets)
      role_key = normalize_role_name(role_name)
      @role_permissions[role_key] ||= []
      @role_permissions[role_key] |= Array(permission_sets)
    end

    # Clears all permission sets from a role.
    #
    # @param role_name [Symbol, String] the name of the role
    # @return [Array<Class>] the removed permission sets
    def clear(role_name)
      role_key = normalize_role_name(role_name)
      @role_permissions.delete(role_key)
    end

    # Returns the permission sets assigned to a role.
    #
    # @param role_name [Symbol, String] the name of the role
    # @return [Array<Class>] the assigned permission sets
    def permission_sets_for(role_name)
      role_key = normalize_role_name(role_name)
      @role_permissions[role_key] || []
    end

    # Returns all permission sets for multiple roles.
    #
    # @param role_names [Array<Symbol, String>] the names of the roles
    # @return [Array<Class>] the combined permission sets (deduplicated)
    def permission_sets_for_roles(role_names)
      role_names.flat_map { |role_name| permission_sets_for(role_name) }.uniq
    end

    # Returns all configured roles.
    #
    # @return [Array<Symbol>] the configured role names
    def roles
      @role_permissions.keys
    end

    # Checks if a role has any permission sets assigned.
    #
    # @param role_name [Symbol, String] the name of the role
    # @return [Boolean]
    def role_configured?(role_name)
      role_key = normalize_role_name(role_name)
      @role_permissions.key?(role_key) && @role_permissions[role_key].any?
    end

    # Resets all role permissions to empty state.
    # Useful for testing.
    def reset!
      @role_permissions = {}
    end

    private

    def normalize_role_name(role_name)
      role_name.to_s.downcase.to_sym
    end
  end
end
