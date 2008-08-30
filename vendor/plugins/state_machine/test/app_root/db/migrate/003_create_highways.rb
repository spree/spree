class CreateHighways < ActiveRecord::Migration
  def self.up
    create_table :highways do |t|
      t.string :name, :null => false
    end
  end
  
  def self.down
    drop_table :highways
  end
end
