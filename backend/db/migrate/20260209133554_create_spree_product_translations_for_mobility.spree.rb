# This migration comes from spree (originally 20220715083542)
class CreateSpreeProductTranslationsForMobility < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_product_translations, :meta_description, :text, if_not_exists: true
    add_column :spree_product_translations, :meta_keywords, :string, if_not_exists: true
    add_column :spree_product_translations, :meta_title, :string, if_not_exists: true
  end
end
