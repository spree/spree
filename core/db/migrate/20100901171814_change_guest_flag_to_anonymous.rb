class ChangeGuestFlagToAnonymous < ActiveRecord::Migration
  def self.up
    rename_column :users, :guest, :anonymous
  end

  def self.down
    rename_column :users, :anonymous, :guest
  end
end
