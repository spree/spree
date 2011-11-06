class RenameCouponsToPromotions < ActiveRecord::Migration
  def up
    drop_table :promotions if table_exists?(:promotions)
    rename_table :coupons, :promotions
  end

  def down
    rename_table :promotions, :coupons
  end
end
