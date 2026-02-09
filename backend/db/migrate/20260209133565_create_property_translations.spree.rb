# This migration comes from spree (originally 20230109105943)
class CreatePropertyTranslations < ActiveRecord::Migration[6.1]
  def change
    if ActiveRecord::Base.connection.table_exists?('spree_property_translations')
      # manually check for index since Rails if_exists does not always work correctly
      if ActiveRecord::Migration.connection.index_exists?(:spree_property_translations, :spree_property_id)
        remove_index :spree_property_translations, column: :spree_property_id, if_exists: true
      end
    else
      create_table :spree_property_translations do |t|
        # Translated attribute(s)
        t.string :presentation

        t.string  :locale, null: false
        t.references :spree_property, null: false, foreign_key: true, index: false

        t.timestamps
      end

      add_index :spree_property_translations, :locale, name: :index_spree_property_translations_on_locale
    end

    add_index :spree_property_translations, [:spree_property_id, :locale], name: :unique_property_id_per_locale, unique: true
  end
end
