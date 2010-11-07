class DropAnonymousFieldForUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :anonymous
  end

  def self.down
  end
end
