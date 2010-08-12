class RenamePreferencesField < ActiveRecord::Migration
  def self.up
    rename_column(:preferences, :attribute, :name)
  end

  def self.down
  end
end
