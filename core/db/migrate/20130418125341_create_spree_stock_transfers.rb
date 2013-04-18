class CreateSpreeStockTransfers < ActiveRecord::Migration
  def change
    create_table :spree_stock_transfers do |t|
      t.string :type
      t.timestamps
    end
  end
end
