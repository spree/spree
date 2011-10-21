class CheckoutStateMachine < ActiveRecord::Migration
  def self.up
    add_column :checkouts, :state, :string
  end

  def self.down
    remove_column :checkouts, :state
  end
end
