class CreateStateEvents < ActiveRecord::Migration
  def self.up
    create_table :state_events do |t|
      t.references :order
      t.references :user
      t.string :name
      t.timestamps
    end    
    drop_table :order_operations
  end

  def self.down
    drop_table :state_events
  end
end
