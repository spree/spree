class RenameCouponsToPromotions < ActiveRecord::Migration
  def self.up
    drop_table :promotions if self.table_exists?(:promotions)
    rename_table :coupons, :promotions
  end

  def self.down
    rename_table :promotions, :coupons
  end
end