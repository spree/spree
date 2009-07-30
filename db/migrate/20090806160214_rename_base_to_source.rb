class RenameBaseToSource < ActiveRecord::Migration
  def self.up
    rename_column :adjustments, :adjustment_base_id, :adjustment_source_id
    rename_column :adjustments, :adjustment_base_type, :adjustment_source_type
  end

  def self.down
    rename_column :adjustments, :adjustment_source_id, :adjustment_base_id
    rename_column :adjustments, :adjustment_source_type, :adjustment_base_type
  end
end
