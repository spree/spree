class AddBackorderLimitToSpreeVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_variants, :backorder_limit, :integer
  end
end
