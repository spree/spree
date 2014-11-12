class RenameShippingMethodsZonesToSpreeShippingMethodsZones < ActiveRecord::Migration
  def change
    rename_table :shipping_methods_zones, :spree_shipping_methods_zones
    # If Spree::ShippingMethod zones association was patched in
    # CreateShippingMethodZone migrations, it needs to be patched back
    Spree::ShippingMethod.has_and_belongs_to_many :zones, :join_table => 'spree_shipping_methods_zones',
                                                          :class_name => 'Spree::Zone',
                                                          :foreign_key => 'shipping_method_id'
  end
end
