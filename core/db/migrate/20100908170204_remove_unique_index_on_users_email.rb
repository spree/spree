class RemoveUniqueIndexOnUsersEmail < ActiveRecord::Migration
  def self.up
    remove_index :users, :email
  end

  def self.down
    add_index :users, :email, :unique => true
  end
end
