class AddGuestFlag < ActiveRecord::Migration
  def change
    unless defined?(User)
      add_column :users, :guest, :boolean
    end
  end
end
