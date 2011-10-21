class DropOrderToken < ActiveRecord::Migration
  def self.up
    remove_column :orders, :token
  end

  def self.down
    add_column :orders, :token, :string
  end
end
