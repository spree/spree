class RenameCostToAmountOnShipments < ActiveRecord::Migration
  def change
    rename_column :spree_shipments, :cost, :amount
  end
end
