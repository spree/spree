class CreatePromotionBatches < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_promotion_batches do |t|
      t.string :state
      t.text :codes

      t.references :template_promotion, foreign_key: { to_table: :spree_promotions }
      t.timestamps
    end
  end
end
