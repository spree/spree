class UpdateCalculableTypeForPromotions < ActiveRecord::Migration
  def self.up
    Spree::Calculator.update_all('calculable_type = "Promotion"', 'calculable_type = "Coupon"')
  end

  def self.down
    Spree::Calculator.update_all('calculable_type = "Coupon"', 'calculable_type = "Promotion"')
  end
end
