class DropAnonymousFieldForUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :anonymous
  end

  def self.down
    add_column :users, :anonymous, :boolean
  end
end
