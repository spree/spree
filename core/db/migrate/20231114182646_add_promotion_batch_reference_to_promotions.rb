class AddPromotionBatchReferenceToPromotions < ActiveRecord::Migration[7.1]
  def change
    add_reference(:spree_promotions, :promotion_batch)
  end
end
