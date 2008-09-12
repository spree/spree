class RefactorOrderState < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.rename :checkout_state, :state
      t.boolean :checkout_complete
    end
    
    # migrate any existing orders
    execute "update orders set state = 'in_progress' WHERE status = 1"
    execute "update orders set state = 'authorized' WHERE status = 2"
    execute "update orders set state = 'captured' WHERE status = 3"
    execute "update orders set state = 'canceled' WHERE status = 4"
    execute "update orders set state = 'returned' WHERE status = 5"
    execute "update orders set state = 'shipped' WHERE status = 6"
    execute "update orders set state = 'paid' WHERE status = 7"
    execute "update orders set state = 'pending_payment' WHERE status = 8"
    execute "update orders set state = 'in_progress' WHERE status = 9"
    
    change_table :orders do |t|
      t.remove :status
    end
    
  end

  def self.down
    change_table :orders do |t|
      t.rename :state, :checkout_state
      t.remove :checkout_complete
      t.integer :status
    end
  end
end

