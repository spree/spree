# Permission set for full order management.
#
# This permission set provides complete access to manage orders,
# including creating, updating, and processing payments and shipments.
#
# @example
#   Spree.permissions.assign(:order_manager, Spree::PermissionSets::OrderManagement)
#
module Spree
  module PermissionSets
    class OrderManagement < Base
      def activate!
        can :manage, Spree::Order
        can :manage, Spree::Payment
        can :manage, Spree::Shipment
        can :manage, Spree::Adjustment
        can :manage, Spree::LineItem
        can :manage, Spree::ReturnAuthorization
        can :manage, Spree::CustomerReturn
        can :manage, Spree::Reimbursement
        can :manage, Spree::Refund
        can :manage, Spree::StoreCredit
        can :manage, Spree::GiftCard

        # Order-specific restrictions
        cannot :cancel, Spree::Order
        can :cancel, Spree::Order, &:allow_cancel?
        cannot :destroy, Spree::Order
        can :destroy, Spree::Order, &:can_be_deleted?
      end
    end
  end
end
