# This migration comes from spree (originally 20250113180019)
class AddPreferencesToSpreeStores < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_stores, :preferences, :text, if_not_exists: true
  end
end
