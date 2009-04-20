class RemoveViewableIdFromProducts < ActiveRecord::Migration
  def self.up       
    change_table :products do |t|
      t.remove :viewable_id
    end
  end

  def self.down
  end
end
