# This migration comes from spree (originally 20220706112554)
class CreateProductNameAndDescriptionTranslationsForMobilityTableBackend < ActiveRecord::Migration[6.1]
  def change
    # create translation table only if spree_globalize has not already created it
    if ActiveRecord::Base.connection.table_exists? 'spree_product_translations'
      # manually check for index since Rails if_exists does not always work correctly
      if ActiveRecord::Migration.connection.index_exists?(:spree_product_translations, :spree_product_id)
        remove_index :spree_product_translations, name: "index_spree_product_translations_on_spree_product_id", if_exists: true
      end
    else
      create_table :spree_product_translations do |t|

        # Translated attribute(s)
        t.string :name
        t.text :description

        t.string  :locale, null: false
        t.references :spree_product, null: false, foreign_key: true, index: false

        t.timestamps null: false
      end

      add_index :spree_product_translations, :locale, name: :index_spree_product_translations_on_locale
    end

    add_index :spree_product_translations, [:spree_product_id, :locale], name: :unique_product_id_per_locale, unique: true
  end
end
