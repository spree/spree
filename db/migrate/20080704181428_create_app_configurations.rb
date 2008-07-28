class CreateAppConfigurations < ActiveRecord::Migration
  def self.up
    create_table :app_configurations do |t|
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :app_configurations
  end
end
