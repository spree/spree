class ConvertUserRememberField < ActiveRecord::Migration
  def self.up
    change_column :users, :remember_created_at, :datetime
  end

  def self.down
    change_column :users, :remember_created_at, :string
  end
end