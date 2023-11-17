class AddPromotionBatchReferenceToPromotions < ActiveRecord::Migration[7.1]
  def change
    add_reference(:spree_promotions, :promotion_batch, foreign_key: { to_table: :spree_promotion_batches})
  end
end
