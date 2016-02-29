class DowncasePromotionCodesValues < ActiveRecord::Migration
  def up
    Spree::PromotionCode.update_all("value = lower(value)")
    Spree::Promotion.where.not(code: nil).update_all("code = lower(code)")
  end

  def down
    # Not reversible
  end
end
