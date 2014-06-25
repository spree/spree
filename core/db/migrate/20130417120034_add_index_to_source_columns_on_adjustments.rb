class AddIndexToSourceColumnsOnAdjustments < ActiveRecord::Migration
  def change
    add_index :spree_adjustments, [:source_type, :source_id]
  end
end
