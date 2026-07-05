class AddProcessingGroupsToSpreeImports < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_imports, :processing_groups_count, :integer, default: 0
    add_column :spree_imports, :completed_groups_count, :integer, default: 0
  end
end
