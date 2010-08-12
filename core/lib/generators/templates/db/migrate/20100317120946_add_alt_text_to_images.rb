class AddAltTextToImages < ActiveRecord::Migration
  def self.up
    add_column :assets, :alt, :text
  end

  def self.down
    remove_column :assets, :alt
  end
end
