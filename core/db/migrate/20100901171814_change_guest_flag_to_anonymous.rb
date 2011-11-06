class ChangeGuestFlagToAnonymous < ActiveRecord::Migration
  def change
    rename_column :users, :guest, :anonymous
  end
end
