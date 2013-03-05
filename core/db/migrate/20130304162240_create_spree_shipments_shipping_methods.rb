class CreateSpreeShipmentsShippingMethods < ActiveRecord::Migration
  def up
    create_table :spree_shipment_shipping_methods do |t|
      t.belongs_to :shipment
      t.belongs_to :shipping_method
      t.boolean :selected, :default => false
    end
    add_index(:spree_shipment_shipping_methods, [:shipment_id, :shipping_method_id],
              :name => 'spree_shipment_shipping_methods_index',
              :unique => true)

    Spree::Shipment.all.each do |shipment|
      shipping_method = Spree::ShippingMethod.find(shipment.shipment_method_id)
      shipment.add_shipping_method(shipping_method, true)
    end
  end

  def down
    add_column :spree_shipments, :shipping_method_id, :integer
    drop_table :spree_shipment_shipping_methods
  end
end
