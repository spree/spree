class MigrateAdjustments < ActiveRecord::Migration
  def self.up
    execute('update spree_adjustments set amount = 0.0 where amount is null')
    #execute('update spree_adjustments set mandatory = 'true', locked = 'true'')
  end

  def self.down
  end
end
