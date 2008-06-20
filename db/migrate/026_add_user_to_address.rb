class AddUserToAddress < ActiveRecord::Migration
  def self.up
    add_column :addresses, :user_id, :integer
  end

  def self.down
    remove_column :addresses, :user_id
  end
end
