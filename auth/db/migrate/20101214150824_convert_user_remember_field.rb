class ConvertUserRememberField < ActiveRecord::Migration
  def self.up
    remove_column :users, :remember_created_at
    add_column :users, :remember_created_at, :datetime
  end

  def self.down
    remove_column :users, :remember_created_at
    add_column :users, :remember_created_at, :string
  end
end