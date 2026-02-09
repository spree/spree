# This migration comes from spree (originally 20230109084253)
class CreateProductPropertyTranslations < ActiveRecord::Migration[6.1]
  def change
    if ActiveRecord::Base.connection.table_exists? 'spree_product_property_translations'
      # manually check for index since Rails if_exists does not always work correctly
      if ActiveRecord::Migration.connection.index_exists?(:spree_product_property_translations, :spree_product_property_id)
        remove_index :spree_product_property_translations, column: :spree_product_property_id, if_exists: true
      end
    else
      create_table :spree_product_property_translations do |t|
        # Translated attribute(s)
        t.string :value

        t.string  :locale, null: false
        t.references :spree_product_property, null: false, foreign_key: true, index: false

        t.timestamps
      end

      add_index :spree_product_property_translations, :locale, name: :index_spree_product_property_translations_on_locale
    end

    add_index :spree_product_property_translations, [:spree_product_property_id, :locale], name: :unique_product_property_id_per_locale, unique: true
  end
end
