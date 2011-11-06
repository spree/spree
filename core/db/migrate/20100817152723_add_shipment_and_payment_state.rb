class AddShipmentAndPaymentState < ActiveRecord::Migration
  def change
    add_column :orders, :shipment_state, :string
    add_column :orders, :payment_state, :string
  end
end