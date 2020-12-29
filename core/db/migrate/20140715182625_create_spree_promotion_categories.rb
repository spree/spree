class CreateSpreePromotionCategories < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_promotion_categories do |t|
      t.string :name
      t.timestamps null: false, precision: 6
    end

    add_column :spree_promotions, :promotion_category_id, :integer
    add_index :spree_promotions, :promotion_category_id
  end
end
