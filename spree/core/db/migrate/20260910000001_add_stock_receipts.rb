class AddStockReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_stock_receipts do |t|
      t.string :number, null: false
      t.references :store, null: false
      t.references :receivable, polymorphic: true, null: false
      t.string :reference
      t.datetime :received_at, null: false
      t.bigint :received_by_id
      t.text :notes
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end
    add_index :spree_stock_receipts, :number, unique: true
    add_index :spree_stock_receipts, :received_by_id

    create_table :spree_stock_receipt_items do |t|
      t.references :stock_receipt, null: false
      t.references :line, polymorphic: true, null: false
      t.integer :quantity_accepted, null: false, default: 0
      t.integer :quantity_rejected, null: false, default: 0
      t.string :rejection_reason
      t.text :notes
      t.timestamps
    end

    add_column :spree_purchase_order_items, :quantity_rejected, :integer, null: false, default: 0
    add_column :spree_stock_transfer_items, :quantity_rejected, :integer, null: false, default: 0
    remove_column :spree_stock_transfer_items, :discrepancy_reason, :string

    add_column :spree_purchase_orders, :cancel_by, :date
    add_column :spree_purchase_orders, :closed_short_at, :datetime
    add_column :spree_purchase_orders, :close_reason, :text
    add_column :spree_stock_transfers, :closed_short_at, :datetime
    add_column :spree_stock_transfers, :close_reason, :text

    add_column :spree_stock_movements, :stock_receipt_id, :bigint
    add_index :spree_stock_movements, :stock_receipt_id
  end
end
