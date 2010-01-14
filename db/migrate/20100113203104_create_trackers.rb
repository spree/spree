class CreateTrackers < ActiveRecord::Migration
  def self.up
    create_table :trackers do |t|
      t.string :environment
      t.string :analytics_id
      t.boolean :active, :default => true
      t.timestamps
    end
  end

  def self.down
    drop_table :trackers
  end
end
