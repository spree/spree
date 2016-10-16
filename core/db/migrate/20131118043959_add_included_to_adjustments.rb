class AddIncludedToAdjustments < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_adjustments, :included, :boolean, default: false unless Spree::Adjustment.column_names.include?("included")
  end
end
