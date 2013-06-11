class RenameShippingMethodsZonesToSpreeShippingMethodsZones < ActiveRecord::Migration
  def change
    rename_table :shipping_methods_zones, :spree_shipping_methods_zones
  end
end
