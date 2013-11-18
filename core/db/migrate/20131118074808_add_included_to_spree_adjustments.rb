class AddIncludedToSpreeAdjustments < ActiveRecord::Migration
  def change
    add_column :spree_adjustments, :included, :boolean, :default => false
  end
end
