class DropOrderToken < ActiveRecord::Migration
  def up
    remove_column :orders, :token
  end

  def down
    add_column :orders, :token, :string
  end
end
