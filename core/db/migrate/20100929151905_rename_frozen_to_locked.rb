class RenameFrozenToLocked < ActiveRecord::Migration
  def self.up
    rename_column :adjustments, :frozen, :locked
  end

  def self.down
    rename_column :adjustments, :locked, :frozen
  end
end
