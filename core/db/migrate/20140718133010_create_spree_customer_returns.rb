class CreateSpreeCustomerReturns < ActiveRecord::Migration
  def change
    create_table :spree_customer_returns do |t|
      t.string :number
      t.integer :stock_location_id
      t.timestamps null: false
    end
  end
end
