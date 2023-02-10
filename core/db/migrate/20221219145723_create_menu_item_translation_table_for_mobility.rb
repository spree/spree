class CreateMenuItemTranslationTableForMobility < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_menu_item_translations do |t|
      # Translated attribute(s)
      t.string :name
      t.string :subtitle
      t.string :destination

      t.string  :locale, null: false
      t.references :spree_menu_item, null: false, foreign_key: true, index: false

      t.timestamps null: false
    end
    add_index :spree_menu_item_translations, :locale, name: :index_spree_menu_item_translations_on_locale
    add_index :spree_menu_item_translations, [:spree_menu_item_id, :locale], name: :index_2f1dad0e4e37c6c8147f0b351198ff0013d9cc4d, unique: true
  end
end
