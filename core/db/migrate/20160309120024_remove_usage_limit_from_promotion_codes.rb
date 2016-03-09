class RemoveUsageLimitFromPromotionCodes < ActiveRecord::Migration
  def change
    remove_column :spree_promotion_codes, :usage_limit, :integer
  end
end
