# This migration comes from spree (originally 20230103151034)
class CreateOptionValueTranslations < ActiveRecord::Migration[6.1]
  def change
    if ActiveRecord::Base.connection.table_exists? 'spree_option_value_translations'
      # manually check for index since Rails if_exists does not always work correctly
      if ActiveRecord::Migration.connection.index_exists?(:spree_option_value_translations, :spree_option_value_id)
        remove_index :spree_option_value_translations, column: :spree_option_value_id, if_exists: true
      end
    else
      create_table :spree_option_value_translations do |t|

        # Translated attribute(s)
        t.string :presentation

        t.string  :locale, null: false
        t.references :spree_option_value, null: false, foreign_key: true, index: false

        t.timestamps
      end

      add_index :spree_option_value_translations, :locale, name: :index_spree_option_value_translations_on_locale
    end

    add_index :spree_option_value_translations, [:spree_option_value_id, :locale], name: :unique_option_value_id_per_locale, unique: true
  end
end
