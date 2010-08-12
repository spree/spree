class CheckoutStateMachine < ActiveRecord::Migration
  def self.up
    change_table :checkouts do |t|
      t.string :state
    end
  end

  def self.down
    change_table :checkouts do |t|
      t.remove :state
    end
  end
end
