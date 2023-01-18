class CreateMenuTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_menu_translations do |t|
      # Translated attribute(s)
      t.string :name

      t.string  :locale, null: false
      t.references :spree_menu, null: false, foreign_key: true, index: false

      t.timestamps null: false
    end

    add_index :spree_menu_translations, :locale, name: :index_spree_menu_translations_on_locale
    add_index :spree_menu_translations, [:spree_menu_id, :locale], name: :index_spree_menu_translations_on_spree_menu_id_and_locale, unique: true
  end
end
