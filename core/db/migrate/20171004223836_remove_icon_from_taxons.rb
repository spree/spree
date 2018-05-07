class RemoveIconFromTaxons < ActiveRecord::Migration[5.1]
  def change
    remove_column :spree_taxons, :icon_file_name if column_exists? :spree_taxons, :icon_file_name
    remove_column :spree_taxons, :icon_content_type if column_exists? :spree_taxons, :icon_content_type
    remove_column :spree_taxons, :icon_file_size if column_exists? :spree_taxons, :icon_file_size
    remove_column :spree_taxons, :icon_updated_at if column_exists? :spree_taxons, :icon_updated_at
  end
end
