class FixExistingCouponCredits < ActiveRecord::Migration
  def self.up
    execute("UPDATE adjustments SET type='PromotionCredit' WHERE type='CouponCredit'")
    execute("UPDATE adjustments SET adjustment_source_type='Promotion' WHERE adjustment_source_type='Coupon'")
  end

  def self.down
  end
end