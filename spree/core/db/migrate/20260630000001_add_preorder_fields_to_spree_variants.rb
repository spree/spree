class AddPreorderFieldsToSpreeVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_variants, :preorderable, :boolean, if_not_exists: true
    add_column :spree_variants, :preorder_ships_at, :datetime, if_not_exists: true
    add_column :spree_variants, :backorder_limit, :integer, if_not_exists: true
  end
end
