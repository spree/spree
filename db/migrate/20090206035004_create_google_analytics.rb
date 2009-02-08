class CreateGoogleAnalytics < ActiveRecord::Migration
  def self.up
    create_table :google_analytics do |t|
      t.string :analytics_id
      t.boolean :is_active

      t.timestamps
    end
  end

  def self.down
    drop_table :google_analytics
  end
end
