class AddSourceAndDestinationToStockMovements < ActiveRecord::Migration
  def change
    change_table :spree_stock_movements do |t|
      t.references :source, polymorphic: true
      t.references :destination, polymorphic: true
    end
  end
end
