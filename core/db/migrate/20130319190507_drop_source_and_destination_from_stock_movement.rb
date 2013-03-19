class DropSourceAndDestinationFromStockMovement < ActiveRecord::Migration
  def up
    remove_column :spree_stock_movements, :source, polymorphic: true
    remove_column :spree_stock_movements, :destination, polymorphic: true
  end

  def down
    change_table :spree_stock_movements do |t|
      t.references :source, polymorphic: true
      t.references :destination, polymorphic: true
    end
  end
end
