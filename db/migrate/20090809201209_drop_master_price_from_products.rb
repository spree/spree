class DropMasterPriceFromProducts < ActiveRecord::Migration
  def self.up
    change_table :products do |t|
      t.remove :master_price
    end
  end

  def self.down
    change_table :products do |t|
      t.decimal :master_price, :precision => 8, :scale => 2
    end
  end
end
