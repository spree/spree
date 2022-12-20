class CreateProductNameAndDescriptionTranslationsForMobilityTableBackend < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_product_translations do |t|

      # Translated attribute(s)
      t.string :name
      t.text :description

      t.string  :locale, null: false
      t.references :spree_product, null: false, foreign_key: true, index: false

      t.timestamps null: false
    end

    add_index :spree_product_translations, :locale, name: :index_spree_product_translations_on_locale
    add_index :spree_product_translations, [:spree_product_id, :locale], name: :index_89f757462683439a75913375358673bb7f45ebe0, unique: true

  end
end
