class CreatePendingPromotions < ActiveRecord::Migration
  def change
    create_table :pending_promotions do |t|
      t.references :user
      t.references :promotion
    end

    add_index :pending_promotions, :user_id
    add_index :pending_promotions, :promotion_id
  end
end
