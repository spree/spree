class RenameTrackerKindField < ActiveRecord::Migration[5.1]
  def change
    rename_column :spree_trackers, :kind, :engine
  end
end
