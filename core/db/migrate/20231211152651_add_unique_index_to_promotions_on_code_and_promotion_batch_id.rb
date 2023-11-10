class AddUniqueIndexToPromotionsOnCodeAndPromotionBatchId < ActiveRecord::Migration[6.1]
  def change
    add_index(:spree_promotions, [:code, :promotion_batch_id], unique: true)
  end
end
