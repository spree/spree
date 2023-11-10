class AddTemplatePromotionIdToPromotionBatches < ActiveRecord::Migration[6.1]
  def change
    add_reference(:spree_promotion_batches, :template_promotion, foreign_key: { to_table: :spree_promotions })
  end
end
