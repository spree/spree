class AddCostPrice < ActiveRecord::Migration
  def self.up
    add_column :variants, :cost_price, :decimal, :null => true, :default => nil, :precision => 8, :scale => 2
  end

  def self.down
    remove_column :variants, :cost_price
  end
end
