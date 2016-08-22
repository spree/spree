class AddPrimaryToSpreeProductsTaxons < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_products_taxons, :id, :primary_key
  end
end
