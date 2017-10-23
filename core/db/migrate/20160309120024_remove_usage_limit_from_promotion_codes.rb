class RemoveUsageLimitFromPromotionCodes < ActiveRecord::Migration[5.1]
  def change
    remove_column :spree_promotion_codes, :usage_limit, :integer
  end
end
