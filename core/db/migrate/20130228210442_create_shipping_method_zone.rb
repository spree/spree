class CreateShippingMethodZone < ActiveRecord::Migration
  def up
    create_table :shipping_methods_zones, :id => false do |t|
      t.integer :shipping_method_id
      t.integer :zone_id
    end

    Spree::ShippingMethod.all.each{|sm| sm.zones << Spree::Zone.find(sm.zone_id)}

    remove_column :zone_id, :spree_shipping_methods
  end

  def down
    drop_table :shipping_methods_zones
    add_column :spree_shipping_methods, :zone_id, :integer
  end
end
