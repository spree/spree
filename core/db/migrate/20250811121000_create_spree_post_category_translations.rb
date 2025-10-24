class CreateSpreePostCategoryTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_post_category_translations do |t|
      t.references :spree_post_category, null: false, foreign_key: { to_table: :spree_post_categories }
      t.string :locale, null: false
      t.string :title
      t.string :slug
      t.text :description

      t.timestamps

      t.index [:spree_post_category_id, :locale], unique: true
      t.index :slug
    end
  end
end
