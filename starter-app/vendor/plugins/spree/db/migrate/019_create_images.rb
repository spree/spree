class CreateImages < ActiveRecord::Migration
  def self.up
    create_table :images do |t|
      t.integer :viewable_id
      t.string :viewable_type
      t.integer :parent_id
      t.string :content_type
      t.string :filename
      t.integer :size
      t.integer :height
      t.integer :width
      t.string :thumbnail
      t.integer :position
    end
  end

  def self.down
    drop_table :images
  end
end