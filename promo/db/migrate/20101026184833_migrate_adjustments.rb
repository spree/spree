class MigrateAdjustments < ActiveRecord::Migration
  def up
    execute "UPDATE spree_adjustments SET amount = 0.0 WHERE amount IS NULL"
    execute "UPDATE spree_adjustments SET mandatory = 't' WHERE locked = 't'"
  end

  def down
  end
end
