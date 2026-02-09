# This migration comes from spree (originally 20250120152208)
class AddDefaultLocaleToActionTextRichTexts < ActiveRecord::Migration[6.1]
  def change
    if ActionText::RichText.column_defaults['locale'].nil?
      change_column_default :action_text_rich_texts, :locale, from: nil, to: :en
    end
  end
end
