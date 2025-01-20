class AddDefaultLocaleToActionTextRichTexts < ActiveRecord::Migration[7.2]
  def change
    if ActionText::RichText.column_defaults['locale'].nil?
      change_column_default :action_text_rich_texts, :locale, from: nil, to: :en
    end
  end
end
