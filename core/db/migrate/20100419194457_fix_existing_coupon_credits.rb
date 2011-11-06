class Adjustment < ActiveRecord::Base; end;

class FixExistingCouponCredits < ActiveRecord::Migration
  def up
    Adjustment.where(:type => 'CouponCredit').update_all(:type => 'PromotionCredit')
    Adjustment.where(:adjustment_source_type => 'Coupon').update_all(:adjustment_source_type => 'Promotion')
  end

  def down
    Adjustment.where(:adjustment_source_type => 'Promotion').update_all(:adjustment_source_type => 'Coupon')
    Adjustment.where(:type => 'PromotionCredit').update_all(:type => 'CouponCredit')
  end
end
