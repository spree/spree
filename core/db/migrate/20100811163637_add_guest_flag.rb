class AddGuestFlag < ActiveRecord::Migration
  def self.up
    add_column :users, :guest, :boolean
  end

  def self.down
    remove_column :users, :guest
  end
end
