class AddAccountIdToPhotos < ActiveRecord::Migration
  def self.up
    add_column :photos, :account_id, :integer
  end

  def self.down
    remove_column :photos, :account_id
  end
end
