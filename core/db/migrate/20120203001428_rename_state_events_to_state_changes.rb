class RenameStateEventsToStateChanges < ActiveRecord::Migration
  def up
    rename_table :spree_state_events, :spree_state_changes
  end

  def down
    rename_table :spree_state_changes, :spree_state_events
  end
end
