class CreateSpreeTaxonNameAndDescriptionTranslationsForMobilityTableBackend < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_taxon_translations do |t|

      # Translated attribute(s)
      t.string :name
      t.text :description

      t.string  :locale, null: false
      t.references :spree_taxon, null: false, foreign_key: true, index: false

      t.timestamps null: false
    end

    add_index :spree_taxon_translations, :locale, name: :index_spree_taxon_translations_on_locale
    add_index :spree_taxon_translations, [:spree_taxon_id, :locale], name: :index_spree_taxon_translations_on_spree_taxon_id_and_locale, unique: true

  end
end
