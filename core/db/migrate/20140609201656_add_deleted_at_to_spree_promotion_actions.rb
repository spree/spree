class AddDeletedAtToSpreePromotionActions < ActiveRecord::Migration
  def change
    add_column :spree_promotion_actions, :deleted_at, :datetime
    add_index :spree_promotion_actions, :deleted_at
  end
end
