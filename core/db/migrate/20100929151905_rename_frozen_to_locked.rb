class RenameFrozenToLocked < ActiveRecord::Migration
  def change
    rename_column :adjustments, :frozen, :locked
  end
end
