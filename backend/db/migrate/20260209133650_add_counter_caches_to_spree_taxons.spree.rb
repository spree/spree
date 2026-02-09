# This migration comes from spree (originally 20260119170000)
class AddCounterCachesToSpreeTaxons < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_taxons, :children_count, :integer, default: 0, null: false, if_not_exists: true
    add_column :spree_taxons, :classification_count, :integer, default: 0, null: false, if_not_exists: true

    add_index :spree_taxons, :children_count, if_not_exists: true
    add_index :spree_taxons, :classification_count, if_not_exists: true
  end
end
