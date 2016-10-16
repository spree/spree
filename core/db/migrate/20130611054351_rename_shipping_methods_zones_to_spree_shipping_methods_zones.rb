class RenameShippingMethodsZonesToSpreeShippingMethodsZones < ActiveRecord::Migration[4.2]
  def change
    rename_table :shipping_methods_zones, :spree_shipping_methods_zones
  end
end
