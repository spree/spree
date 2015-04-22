class CreateSpreePromotionCodes < ActiveRecord::Migration
  def change
    create_table :spree_promotion_codes do |t|
      t.references :promotion, index: true, null: false
      t.string :value, unique: true, null: false
      t.datetime :starts_at
      t.datetime :expires_at
      t.integer :usage_limit

      t.timestamps
    end

    add_index :spree_promotion_codes, :value
    add_index :spree_promotion_codes, :starts_at
    add_index :spree_promotion_codes, :expires_at
  end
end
