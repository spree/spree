class AddImageDimensions < ActiveRecord::Migration
  def self.up
    add_column :assets, :attachment_width,  :integer
    add_column :assets, :attachment_height, :integer
  end


  def self.down
    remove_column :assets, :attachment_width
    remove_column :assets, :attachment_height
  end
end
