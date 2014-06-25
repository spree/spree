class AddTaxCategoryToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :tax_category_id, :integer
    add_index  :spree_variants, :tax_category_id
  end
end
