# Permission set for viewing orders and related resources.
#
# This permission set provides read-only access to orders and associated
# models like payments, shipments, and refunds.
#
# @example
#   Spree.permissions.assign(:customer_service, Spree::PermissionSets::OrderDisplay)
#
module Spree
  module PermissionSets
    class OrderDisplay < Base
      def activate!
        can [:read, :admin, :index], Spree::Order
        can [:read, :admin], Spree::Payment
        can [:read, :admin], Spree::Shipment
        can [:read, :admin], Spree::Adjustment
        can [:read, :admin], Spree::LineItem
        can [:read, :admin], Spree::ReturnAuthorization
        can [:read, :admin], Spree::CustomerReturn
        can [:read, :admin], Spree::Reimbursement
        can [:read, :admin], Spree::Refund
        can [:read, :admin], Spree::StoreCredit
        can [:read, :admin], Spree::GiftCard
      end
    end
  end
end
