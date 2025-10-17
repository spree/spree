class AddTranslationsToPosts < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_post_translations do |t|
      # Translated attribute(s)
      t.string :title
      t.text :content
      t.string :meta_title
      t.text :meta_description
      t.string :meta_keywords
      t.string :slug

      t.string  :locale, null: false
      t.references :spree_post, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :spree_post_translations, :locale, name: :index_spree_post_translations_on_locale
    add_index :spree_post_translations, [:spree_post_id, :locale], name: :index_spree_post_translations_on_post_id_and_locale, unique: true

    # Add index for friendly_id slug
    add_index :spree_post_translations, :slug, name: :index_spree_post_translations_on_slug
  end
end
