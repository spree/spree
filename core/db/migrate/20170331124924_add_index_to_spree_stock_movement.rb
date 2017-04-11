class AddIndexToSpreeStockMovement < ActiveRecord::Migration[5.0]
  def change
    add_index :spree_stock_movements, [:originator_id, :originator_type], name: 'index_stock_movements_on_originator_id_and_originator_type'
  end
end
