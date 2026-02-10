# Permission set for viewing stock and inventory information.
#
# This permission set provides read-only access to stock items,
# locations, and movements.
#
# @example
#   Spree.permissions.assign(:warehouse_viewer, Spree::PermissionSets::StockDisplay)
#
module Spree
  module PermissionSets
    class StockDisplay < Base
      def activate!
        can [:read, :admin, :index], Spree::StockItem
        can [:read, :admin], Spree::StockLocation
        can [:read, :admin], Spree::StockMovement
      end
    end
  end
end
