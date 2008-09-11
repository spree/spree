class ChangeInventoryStateType < ActiveRecord::Migration
  def self.up
    change_column :inventory_units, :state, :string 
  end

  def self.down
  end
end
