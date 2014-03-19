class AddNumberToStockTransfer < ActiveRecord::Migration
  def up
    remove_index :spree_stock_transfers, :source_location_id
    remove_index :spree_stock_transfers, :destination_location_id

    rename_column :spree_stock_transfers, :reference_number, :reference
    add_column :spree_stock_transfers, :number, :string

    Spree::StockTransfer.find_each do |transfer|
      transfer.send(:generate_stock_transfer_number)
      transfer.save!
    end

    add_index :spree_stock_transfers, :number
    add_index :spree_stock_transfers, :source_location_id
    add_index :spree_stock_transfers, :destination_location_id
  end

  def down
    rename_column :spree_stock_transfers, :reference, :reference_number
    remove_column :spree_stock_transfers, :number, :string
  end
end
