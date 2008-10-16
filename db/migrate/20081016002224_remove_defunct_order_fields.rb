class RemoveDefunctOrderFields < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.remove :ship_method
    end
  end

  def self.down
  end
end
