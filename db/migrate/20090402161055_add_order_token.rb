class AddOrderToken < ActiveRecord::Migration
  def self.up 
    change_table :orders do |t|
      t.string :token
    end
  end

  def self.down      
    change_table :orders do |t|
      t.remove :token
    end
  end
end
