class CreateSpreeShippingRates < ActiveRecord::Migration
  def up
    create_table :spree_shipping_rates do |t|
      t.belongs_to :shipment
      t.belongs_to :shipping_method
      t.boolean :selected, :default => false
      t.decimal :cost, :precision => 8, :scale => 2
      t.timestamps
    end
    add_index(:spree_shipping_rates, [:shipment_id, :shipping_method_id],
              :name => 'spree_shipping_rates_join_index',
              :unique => true)

    # Spree::Shipment.all.each do |shipment|
    #   shipping_method = Spree::ShippingMethod.find(shipment.shipment_method_id)
    #   shipment.add_shipping_method(shipping_method, true)
    # end
  end

  def down
    # add_column :spree_shipments, :shipping_method_id, :integer
    drop_table :spree_shipping_rates
  end
end
