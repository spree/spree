class UpdateCalculableTypeForPromotions < ActiveRecord::Migration
  def self.up
    Spree::Calculator.where(:calculable_type => 'Coupon').update_all(:calculable_type => 'Promotion')
  end

  def self.down
    Spree::Calculator.where(:calculable_type => 'Promotion').update_all(:calculable_type => 'Coupon')
  end
end
