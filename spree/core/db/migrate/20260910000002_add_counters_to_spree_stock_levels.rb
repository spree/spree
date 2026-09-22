class AddCountersToSpreeStockLevels < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_stock_levels, :reserved_count, :integer, default: 0, null: false
    add_column :spree_stock_levels, :incoming_count, :integer, default: 0, null: false
  end
end
