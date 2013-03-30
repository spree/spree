class DropSourceAndDestinationFromStockMovement < ActiveRecord::Migration
  def up
    change_table :spree_stock_movements do |t|
      t.remove_references :source, :polymorphic => true
      t.remove_references :destination, :polymorphic => true
    end
  end

  def down
    change_table :spree_stock_movements do |t|
      t.references :source, polymorphic: true
      t.references :destination, polymorphic: true
    end
  end
end
