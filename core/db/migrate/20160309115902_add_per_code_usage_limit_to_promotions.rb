class AddPerCodeUsageLimitToPromotions < ActiveRecord::Migration
  def change
    add_column :spree_promotions, :per_code_usage_limit, :integer
  end
end
