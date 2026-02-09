# This migration comes from spree (originally 20250127112758)
class AddLatitudeAndLongitudeToSpreeAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_addresses, :latitude, :decimal, if_not_exists: true
    add_column :spree_addresses, :longitude, :decimal, if_not_exists: true
  end
end
