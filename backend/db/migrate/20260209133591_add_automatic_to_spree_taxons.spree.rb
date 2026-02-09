# This migration comes from spree (originally 20241128103947)
class AddAutomaticToSpreeTaxons < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_taxons, :automatic, :boolean, default: false, null: false
  end
end
