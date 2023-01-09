class CreatePropertyTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_property_translations do |t|
      # Translated attribute(s)
      t.string :name
      t.string :presentation
      t.string :filter_param

      t.string  :locale, null: false
      t.references :spree_property, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :spree_property_translations, :locale, name: :index_spree_property_translations_on_locale
    add_index :spree_property_translations, [:spree_property_id, :locale], name: :unique_property_id_per_locale, unique: true
  end
end
