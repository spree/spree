class AddPersonnelIdToPhotos < ActiveRecord::Migration
  def self.up
    add_column :photos, :personnel_id, :integer
  end

  def self.down
    remove_column :photos, :personnel_id
  end
end
