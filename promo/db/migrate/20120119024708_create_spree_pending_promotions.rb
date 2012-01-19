class CreateSpreePendingPromotions < ActiveRecord::Migration
  def change
    create_table :spree_pending_promotions do |t|
      t.references :user
      t.references :promotion
    end

    add_index :spree_pending_promotions, :user_id
    add_index :spree_pending_promotions, :promotion_id
  end
end
