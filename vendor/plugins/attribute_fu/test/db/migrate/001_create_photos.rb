class CreatePhotos < ActiveRecord::Migration
  def self.up
    create_table :photos do |t|
      t.string :title
      t.text   :description

      t.timestamps
    end
  end

  def self.down
    drop_table :photos
  end
end
