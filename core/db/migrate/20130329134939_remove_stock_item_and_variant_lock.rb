class RemoveStockItemAndVariantLock < ActiveRecord::Migration
  def up
    # we are moving to pessimistic locking on stock_items
    remove_column :spree_stock_items, :lock_version

    # variants no longer manage their count_on_hand so we are removing their lock
    remove_column :spree_variants, :lock_version
  end

  def down
    add_column :spree_stock_items, :lock_version, :integer
    add_column :spree_variants, :lock_version, :integer
  end
end
