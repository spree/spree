class AddIndexOnUsersPersistenceToken < ActiveRecord::Migration
  def self.up
    add_index :users, :persistence_token
  end

  def self.down
    remove_index :users, :persistence_token
  end
end
