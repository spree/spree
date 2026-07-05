# Permission set for full stock and inventory management.
#
# This permission set provides complete access to manage stock items,
# locations, and movements.
#
# @example
#   Spree.permissions.assign(:warehouse_manager, Spree::PermissionSets::StockManagement)
#
module Spree
  module PermissionSets
    class StockManagement < Base
      def activate!
        can :manage, Spree::StockItem
        can :manage, Spree::StockLocation
        can :manage, Spree::StockMovement
      end
    end
  end
end
