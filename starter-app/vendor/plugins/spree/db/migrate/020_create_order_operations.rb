class CreateOrderOperations < ActiveRecord::Migration
  def self.up
    create_table :order_operations do |t|
      t.integer :order_id
      t.integer :user_id
      t.integer :operation_type
      t.timestamps
    end
  end

  def self.down
    drop_table :order_operations
  end
end