class CheckoutStateMachine < ActiveRecord::Migration
  def change
    add_column :checkouts, :state, :string
  end
end
