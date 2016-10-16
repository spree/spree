class AddIndexToSourceColumnsOnAdjustments < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_adjustments, [:source_type, :source_id]
  end
end
