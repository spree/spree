class CreateSpreePostTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_post_translations do |t|
      t.references :spree_post, null: false, foreign_key: { to_table: :spree_posts }
      t.string :locale, null: false
      t.string :title
      t.string :slug
      t.string :meta_title
      t.string :meta_description
      t.text :content
      t.text :excerpt

      t.timestamps

      t.index [:spree_post_id, :locale], unique: true
      t.index :slug
    end
  end
end
