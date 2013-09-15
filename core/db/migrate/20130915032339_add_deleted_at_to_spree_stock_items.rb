class AddDeletedAtToSpreeStockItems < ActiveRecord::Migration
  def change
    add_column :spree_stock_items, :deleted_at, :datetime
  end
end
