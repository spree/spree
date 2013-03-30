class DropSourceAndDestinationFromStockMovement < ActiveRecord::Migration
  def up
    remove_column :spree_stock_movements, :source_id
    remove_column :spree_stock_movements, :source_type
    remove_column :spree_stock_movements, :destination_id
    remove_column :spree_stock_movements, :destination_type
  end

  def down
    change_table :spree_stock_movements do |t|
      t.references :source, polymorphic: true
      t.references :destination, polymorphic: true
    end
  end
end
