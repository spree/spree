class AddReturnsEnabledToStockLocations < ActiveRecord::Migration[8.1]
  # Which locations accept goods coming back — the inbound twin of
  # pickup_enabled. A merchant who inspects and restocks returns at one
  # processing centre should not have parcels sent to every warehouse that
  # happens to ship orders out.
  #
  # Defaults true so an upgrading store keeps returning goods wherever they
  # shipped from, which is what happened before the flag existed. A merchant
  # narrows it by turning the others off.
  def change
    add_column :spree_stock_locations, :returns_enabled, :boolean, null: false, default: true
    add_index :spree_stock_locations, :returns_enabled
  end
end
