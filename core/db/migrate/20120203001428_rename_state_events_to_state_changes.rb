class RenameStateEventsToStateChanges < ActiveRecord::Migration
  def up
    rename_table :state_events, :state_changes
  end

  def down
    rename_table :state_changes, :state_events
  end
end
