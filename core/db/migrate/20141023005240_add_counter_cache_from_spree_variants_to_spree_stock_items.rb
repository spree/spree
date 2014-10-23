class AddCounterCacheFromSpreeVariantsToSpreeStockItems < ActiveRecord::Migration
  def up
    # Setup the column.
    add_column :spree_variants, :stock_items_count, :integer

    # Reset all of the cached information.
    Spree::Variant.reset_column_information

    # Reset the cached counters for stock items of already
    # existing records.
    Spree::Variant.find_each do |variant|
      Spree::Variant.reset_counters(variant.id, :stock_items)
    end

    # We are doing a defualt and null here because in some databases (pg)
    # you will get an error for having a null value on an existing record.
    # The known hack around this is to perform an add column and then a
    # change column.
    change_column :spree_variants, :stock_items_count, :integer, default: 0, null: false
  end

  def down
    remove_column :spree_variants, :stock_items_count
  end
end
