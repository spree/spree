# Permission set for full user management.
#
# This permission set provides complete access to manage user accounts,
# addresses, and credit cards.
#
# @example
#   Spree.permissions.assign(:customer_service, Spree::PermissionSets::UserManagement)
#
module Spree
  module PermissionSets
    class UserManagement < Base
      def activate!
        can :manage, Spree.user_class
        can :manage, Spree::Address
        can :manage, Spree::CreditCard
        can [:read, :admin], Spree::Metafield
      end
    end
  end
end
