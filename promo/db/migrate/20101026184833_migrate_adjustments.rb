class MigrateAdjustments < ActiveRecord::Migration
  def up
    Spree::Adjustment.where(:amount => nil).update_all(:amount => 0.0)
    Spree::Adjustment.where(:locked => true).update_all(:mandatory => true)
  end

  def down
  end
end
