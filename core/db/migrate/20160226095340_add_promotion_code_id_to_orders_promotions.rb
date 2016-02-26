class AddPromotionCodeIdToOrdersPromotions < ActiveRecord::Migration
  def change
    add_column :spree_order_promotions, :promotion_code_id, :integer
    add_index :spree_order_promotions, :promotion_code_id
  end
end
