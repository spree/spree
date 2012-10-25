class AddForRepairToReturns < ActiveRecord::Migration
  def up
    add_column :spree_return_authorizations, :for_repair, :boolean, :default => false
  end

  def down
    remove_column :spree_return_authorizations, :for_repair
  end
end
