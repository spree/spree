class RenameAppConfiguration < ActiveRecord::Migration
  def self.up
    rename_table :app_configurations, :configurations
    change_table :configurations do |t|
      t.string :type
    end
    execute "UPDATE configurations SET type = 'AppConfiguration' WHERE name = 'Default configuration'"
  end

  def self.down
    change_table :configurations do |t|
      t.remove :type
    end
    rename_table :configurations, :app_configurations 
  end
end
