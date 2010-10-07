class EmailForOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :email, :string
  end

  def self.down
    remove_column :orders, :email
  end
end
