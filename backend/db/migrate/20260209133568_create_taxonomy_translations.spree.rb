# This migration comes from spree (originally 20230117115531)
class CreateTaxonomyTranslations < ActiveRecord::Migration[6.1]
  def change
      if ActiveRecord::Base.connection.table_exists?('spree_taxonomy_translations')
        # manually check for index since Rails if_exists does not always work correctly
        if ActiveRecord::Migration.connection.index_exists?(:spree_taxonomy_translations, :spree_taxonomy_id)
          remove_index :spree_taxonomy_translations, column: :spree_taxonomy_id, if_exists: true
        end
      else
        create_table :spree_taxonomy_translations do |t|
          # Translated attribute(s)
          t.string :name

          t.string  :locale, null: false
          t.references :spree_taxonomy, null: false, foreign_key: true, index: false

          t.timestamps null: false
        end

        add_index :spree_taxonomy_translations, :locale, name: :index_spree_taxonomy_translations_on_locale
      end

      add_index :spree_taxonomy_translations, [:spree_taxonomy_id, :locale], name: :index_spree_taxonomy_translations_on_spree_taxonomy_id_locale, unique: true
  end
end
