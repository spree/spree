class DropCategoryIdFromProducts < ActiveRecord::Migration
  def self.up
    remove_column :products, :category_id
  end

  def self.down
    add_column :products, :category_id, :integer
  end
end
