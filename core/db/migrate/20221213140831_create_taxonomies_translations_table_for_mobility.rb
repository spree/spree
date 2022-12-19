class CreateTaxonomiesTranslationsTableForMobility < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_taxonomy_translations do |t|
      # Translated attribute(s)
      t.string :name

      t.string  :locale, null: false
      t.references :spree_taxonomy, null: false, foreign_key: true, index: false

      t.timestamps null: false
    end
    add_index :spree_taxonomy_translations, :locale, name: :index_spree_taxonomy_translations_on_locale
    add_index :spree_taxonomy_translations, [:spree_taxonomy_id, :locale], name: :index_spree_taxonomy_translations_on_spree_taxonomy_id_locale, unique: true

  end
end
