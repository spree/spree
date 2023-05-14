class AddIndexOnLocaleAndPermalinkToSpreeTaxons < ActiveRecord::Migration[6.1]
  def change
    add_index :spree_taxon_translations, [:locale, :permalink], unique: true, name: 'unique_permalink_per_locale', if_not_exists: true
  end
end
