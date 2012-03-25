class MigrateAdjustments < ActiveRecord::Migration
  def up
    execute "UPDATE spree_adjustments SET amount = 0.0 WHERE amount IS NULL"
    execute "UPDATE spree_adjustments SET mandatory = #{quoted_true} WHERE locked = #{quoted_true}"
  end

  def down
  end
end
