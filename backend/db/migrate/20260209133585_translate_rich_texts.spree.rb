# This migration comes from spree (originally 20241014140140)
class TranslateRichTexts < ActiveRecord::Migration[6.1]
  def change
    if table_exists?(:action_text_rich_texts)
      add_column :action_text_rich_texts, :locale, :string, null: false

      remove_index :action_text_rich_texts,
                   column: [:record_type, :record_id, :name],
                   name: :index_action_text_rich_texts_uniqueness,
                   unique: true

      add_index :action_text_rich_texts,
                  [:record_type, :record_id, :name, :locale],
                  name: :index_action_text_rich_texts_uniqueness,
                  unique: true
    end
  end
end
