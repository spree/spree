class AddAltTextToImages < ActiveRecord::Migration
  def change
    add_column :assets, :alt, :text
  end
end
