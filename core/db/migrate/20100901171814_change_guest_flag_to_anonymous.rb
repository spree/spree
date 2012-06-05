class ChangeGuestFlagToAnonymous < ActiveRecord::Migration
  def change
    unless defined?(User)
      rename_column :users, :guest, :anonymous
    end
  end
end
