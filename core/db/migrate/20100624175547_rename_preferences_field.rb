class RenamePreferencesField < ActiveRecord::Migration
  def change
    rename_column :preferences, :attribute, :name
  end
end
