class AddCounterCacheFromSpreeVariantsToSpreeStockItems < ActiveRecord::Migration
  def up
    add_column :spree_variants, :stock_items_count, :integer, default: 0, null: false

    Spree::Variant.find_each do |variant|
      Spree::Variant.reset_counters(variant.id, :stock_items)
    end
  end

  def down
    remove_column :spree_variants, :stock_items_count
  end
end
