class CreateSpreeProductMetaDescriptionAndMetaKeywordsAndMetaTitleTranslationsForMobilityTableBackend < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_product_translations, :meta_description, :text
    add_column :spree_product_translations, :meta_keywords, :string
    add_column :spree_product_translations, :meta_title, :string
  end
end
