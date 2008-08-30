class CreateSwitches < ActiveRecord::Migration
  def self.up
    create_table :switches do |t|
      t.string :state, :null => false
      t.string :kind
    end
  end
  
  def self.down
    drop_table :switches
  end
end
