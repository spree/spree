class AddPreferencesColumnToSpreeStores < ActiveRecord::Migration
  def up
    add_column :spree_stores, :preferences, :text
  end

  def down
    remove_column :spree_stores, :preferences
  end
end
