class AddStateToSpreeAdjustments < ActiveRecord::Migration
  def change
    add_column :spree_adjustments, :state, :string
    remove_column :spree_adjustments, :locked
  end
end
