class CreateTags < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.column :name, :string
    end
    
    create_table :photos_tags, :id => :false do |t|
      t.column :photo_id, :integer
      t.column :tag_id, :integer
    end
  end

  def self.down
    drop_table :tags
    drop_table :photos_tags
  end
end
