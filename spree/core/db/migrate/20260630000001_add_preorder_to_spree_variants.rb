class AddPreorderToSpreeVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_variants, :preorderable, :boolean
    add_column :spree_variants, :preorder_ships_at, :datetime
  end
end
