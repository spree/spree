class AddTotalOnHandToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :count_on_hand, :integer, null: false, default: 0
  end
end
