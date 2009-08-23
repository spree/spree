class CouponStartsAt < ActiveRecord::Migration
  def self.up
    change_table :coupons do |t|
      t.datetime :starts_at
    end
  end

  def self.down
    chnage_table :coupons do |t|
      t.remove :starts_at
    end
  end
end
