class CreateOptionValueTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_option_value_translations do |t|

      # Translated attribute(s)
      t.string :name
      t.string :presentation

      t.string  :locale, null: false
      t.references :spree_option_value, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :spree_option_value_translations, :locale, name: :index_spree_option_value_translations_on_locale
    add_index :spree_option_value_translations, [:spree_option_value_id, :locale], name: :unique_option_value_id_per_locale, unique: true
  end
end
