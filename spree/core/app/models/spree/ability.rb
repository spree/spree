# Implementation class for Cancan gem. Permissions are configured through
# permission sets — see Spree::PermissionSets::Base for details on creating
# custom ones.
#
# @example Configuring role permissions
#   Spree.permissions.assign(:customer_service, [
#     Spree::PermissionSets::OrderDisplay,
#     Spree::PermissionSets::UserManagement
#   ])
#
# See https://github.com/CanCanCommunity/cancancan for more details.
require 'cancan'

module Spree
  class Ability
    include CanCan::Ability

    # @return [Object] the current user
    attr_reader :user

    # @return [Spree::Store, nil] the current store
    attr_reader :store

    def initialize(user, options = {})
      alias_cancan_delete_action

      @user = user || Spree.user_class.new
      @store = options[:store] || Spree::Current.store

      apply_permissions_from_sets
    end

    protected

    def alias_cancan_delete_action
      alias_action :delete, to: :destroy
      alias_action :create, :update, :destroy, to: :modify
    end

    # Applies permissions based on the user's roles and the configured permission sets.
    def apply_permissions_from_sets
      role_names = determine_role_names
      permission_sets = Spree.permissions.permission_sets_for_roles(role_names)
      activate_permission_sets(permission_sets)
    end

    # Determines the role names for the current user.
    #
    # @return [Array<Symbol>] the role names
    def determine_role_names
      return [:default] unless @user.persisted?

      # First, try to get roles from the spree_roles association
      if @user.respond_to?(:spree_roles)
        role_names = @user.spree_roles.pluck(:name).map(&:to_sym)
        return role_names if role_names.any?
      end

      # Fall back to checking spree_admin? for backward compatibility
      # This supports cases where roles are mocked or admin status is determined differently
      if @user.try(:spree_admin?, @store)
        [:admin]
      else
        [:default]
      end
    end

    # Activates the given permission sets.
    #
    # @param permission_sets [Array<Class>] the permission set classes to activate
    def activate_permission_sets(permission_sets)
      permission_sets.each do |permission_set_class|
        permission_set = permission_set_class.new(self)
        permission_set.activate!
      end
    end
  end
end
