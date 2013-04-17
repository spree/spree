class AddShippingRatesToShipments < ActiveRecord::Migration
  def up
    Spree::Shipment.all.each do |shipment|
      shipment.shipping_rates.create(:shipping_method_id => shipment.shipping_method_id,
                                     :cost => shipment.cost,
                                     :selected => true)
    end

    remove_column :spree_shipments, :shipping_method_id
  end

  def down
    add_column :spree_shipments, :shipping_method_id, :integer
  end
end
