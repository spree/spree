class RenameSpreeWishedProductsToSpreeWishedVariants < ActiveRecord::Migration[5.2]
  def change
    rename_table :spree_wished_products, :spree_wished_variants
  end
end
