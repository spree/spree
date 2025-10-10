class AddPreferencesToSpreeStores < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_stores, :preferences, :text, if_not_exists: true
  end
end
