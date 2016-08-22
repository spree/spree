class RenameReturnAuthorizationInventoryUnitToReturnItems < ActiveRecord::Migration[4.2]
  def change
    rename_table :spree_return_authorization_inventory_units, :spree_return_items
  end
end
