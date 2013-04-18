class CreateSpreeStockTransfers < ActiveRecord::Migration
  def change
    create_table :spree_stock_transfers do |t|
      t.string :type
      t.string :reference_number
      t.integer :source_location_id
      t.integer :destination_location_id
      t.timestamps
    end

    add_index :spree_stock_transfers, :source_location_id
    add_index :spree_stock_transfers, :destination_location_id
  end
end
