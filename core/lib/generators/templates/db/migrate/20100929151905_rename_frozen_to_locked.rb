class RenameFrozenToLocked < ActiveRecord::Migration
  def self.up
    rename_column :adjustments, :frozen, :locked
  end

  def self.down
  end
end
