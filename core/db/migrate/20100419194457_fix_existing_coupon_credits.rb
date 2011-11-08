class Adjustment < ActiveRecord::Base; end;

class FixExistingCouponCredits < ActiveRecord::Migration
  def up
    execute("UPDATE adjustments SET type='PromotionCredit' WHERE type='CouponCredit'")
    execute("UPDATE adjustments SET adjustment_source_type='Promotion' WHERE adjustment_source_type='Coupon'")
  end

  def down
    execute("UPDATE adjustments SET adjustment_source_type='Coupon' WHERE adjustment_source_type='Promotion'")
    execute("UPDATE adjustments SET type='CouponCredit' WHERE type='PromotionCredit'")
  end
end
