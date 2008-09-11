class CreateAutoShops < ActiveRecord::Migration
  def self.up
    create_table :auto_shops do |t|
      t.string :name, :null => false
      t.integer :num_customers, :null => false
      t.string :state, :null => false
    end
  end
  
  def self.down
    drop_table :auto_shops
  end
end
