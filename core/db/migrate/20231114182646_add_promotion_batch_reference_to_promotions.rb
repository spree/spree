class AddPromotionBatchReferenceToPromotions < ActiveRecord::Migration[6.1]
  def change
    add_reference :spree_promotions, :promotion_batch, foreign_key: { to_table: :spree_promotion_batches}
    add_column :spree_promotions, :template, :boolean
  end
end
