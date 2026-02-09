# This migration comes from spree (originally 20240822163534)
class AddPrettyNameToSpreeTaxons < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_taxons, :pretty_name, :string, null: true, if_not_exists: true
    add_index :spree_taxons, :pretty_name, if_not_exists: true

    add_column :spree_taxon_translations, :pretty_name, :string, null: true, if_not_exists: true
    add_index :spree_taxon_translations, :pretty_name, if_not_exists: true
  end
end
