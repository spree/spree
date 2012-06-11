class AddIndexOnUsersPersistenceToken < ActiveRecord::Migration
  def change
    unless defined?(User)
      add_index :users, :persistence_token
    end
  end
end
