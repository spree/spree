class RefactorOrderState < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.rename :checkout_state, :state
      t.boolean :checkout_complete
    end
  end

  def self.down
    change_table :orders do |t|
      t.rename :state, :checkout_state
      t.remove :checkout_complete
    end
  end
end
