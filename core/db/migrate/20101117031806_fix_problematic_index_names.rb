class FixProblematicIndexNames < ActiveRecord::Migration
  def up
    begin
      remove_index :preferences, :name => 'index_preferences_on_owner_and_attribute_and_preference'
    rescue ArgumentError
      # ignore - already remove then
    end
    add_index :preferences, [:owner_id, :owner_type, :name, :group_id, :group_type], :name => 'ix_prefs_on_owner_attr_pref', :unique => true
  end

  def down
  end
end
