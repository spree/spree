class MakeAdjustmentsPolymorphic < ActiveRecord::Migration

  def change
    add_column :spree_adjustments, :adjustable_type, :string
    rename_column :spree_adjustments, :order_id, :adjustable_id
    execute "UPDATE spree_adjustments SET adjustable_type = 'Spree::Order'"
  end

end
