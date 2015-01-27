class CreateSpreePromotionCodes < ActiveRecord::Migration
  def change
    create_table :spree_promotion_codes do |t|
      t.references :promotion, index: true
      t.string :value, unique: true
      t.datetime :starts_at
      t.datetime :expires_at
      t.integer :usage_limit

      t.timestamps
    end
  end
end
