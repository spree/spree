class CreateOrderMutex < ActiveRecord::Migration
  def change
    create_table :spree_order_mutexes do |t|
      t.integer :order_id, null: false

      t.datetime :created_at
    end

    add_index :spree_order_mutexes, :order_id, unique: true
  end
end
