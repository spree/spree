class CreateMenuItemTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_menu_item_translations do |t|
      # translatable fields
      t.string :name
      t.string :subtitle
      t.string :destination

      t.string  :locale, null: false
      t.references :spree_menu_item, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :spree_menu_item_translations, :locale, name: :index_spree_menu_item_translations_on_locale
    add_index :spree_menu_item_translations, [:spree_menu_item_id, :locale], name: :index_spree_menu_item_translations_on_spree_menu_id_and_locale, unique: true
  end
end
