class CreateSpreeStockTransfers < ActiveRecord::Migration
  def change
    create_table :spree_stock_transfers do |t|
      t.string :type
      t.string :reference_number
      t.timestamps
    end
  end
end
