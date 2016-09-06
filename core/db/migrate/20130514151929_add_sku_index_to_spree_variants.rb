class AddSkuIndexToSpreeVariants < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_variants, :sku
  end
end
