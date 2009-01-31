class CreateCssPoints < ActiveRecord::Migration
  def self.up
    create_table :css_points do |t|
      t.string :key
      t.string :value
      t.integer :theme_id
      t.timestamps
    end
  end

  def self.down
    drop_table :css_points
  end
end
