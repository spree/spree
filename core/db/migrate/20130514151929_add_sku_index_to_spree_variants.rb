class AddSkuIndexToSpreeVariants < ActiveRecord::Migration
  def change
    add_index :spree_variants, :sku
  end
end
