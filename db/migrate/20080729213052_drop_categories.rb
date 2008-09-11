class DropCategories < ActiveRecord::Migration
  def self.up
    drop_table :categories
  end

  def self.down
  end
end
