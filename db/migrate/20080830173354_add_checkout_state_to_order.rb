class AddCheckoutStateToOrder < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.string :checkout_state
    end
  end

  def self.down
    change_table :orders do |t|
      t.remove :checkout_state
    end
  end
end
