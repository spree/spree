class CreateSpreeStockReservations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_stock_reservations do |t|
      t.references :stock_item, null: false, index: false
      t.references :line_item, null: false
      t.references :order, null: false
      t.integer :quantity, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    # Composite (stock_item_id, expires_at) is the hot-path Quantifier query;
    # leading on stock_item_id makes it cover the standalone-by-stock-item lookup too.
    add_index :spree_stock_reservations, [:stock_item_id, :expires_at]
    add_index :spree_stock_reservations, [:stock_item_id, :line_item_id], unique: true,
              name: 'idx_stock_reservations_item_line_item'
    add_index :spree_stock_reservations, :expires_at
  end
end
