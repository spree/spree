# Permission set granting full administrative access.
#
# This permission set provides unrestricted access to all resources,
# with some safety restrictions for critical operations.
#
# @example
#   Spree.permissions.assign(:admin, Spree::PermissionSets::SuperUser)
#
module Spree
  module PermissionSets
    class SuperUser < Base
      def activate!
        can :manage, :all

        # Safety restrictions
        cannot :cancel, Spree::Order
        can :cancel, Spree::Order, &:allow_cancel?
        cannot :destroy, Spree::Order
        can :destroy, Spree::Order, &:can_be_deleted?
        cannot [:edit, :update], Spree::RefundReason, mutable: false
        cannot [:edit, :update], Spree::ReimbursementType, mutable: false

        # Protect the admin role from modification
        cannot [:update, :destroy], Spree::Role, name: ['admin']
      end
    end
  end
end
