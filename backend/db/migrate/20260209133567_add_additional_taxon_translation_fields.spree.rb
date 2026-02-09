# This migration comes from spree (originally 20230111121534)
class AddAdditionalTaxonTranslationFields < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_taxon_translations, :meta_title, :string, if_not_exists: true
    add_column :spree_taxon_translations, :meta_description, :string, if_not_exists: true
    add_column :spree_taxon_translations, :meta_keywords, :string, if_not_exists: true
    add_column :spree_taxon_translations, :permalink, :string, if_not_exists: true
  end
end
