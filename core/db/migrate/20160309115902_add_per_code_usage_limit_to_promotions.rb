class AddPerCodeUsageLimitToPromotions < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_promotions, :per_code_usage_limit, :integer
  end
end
