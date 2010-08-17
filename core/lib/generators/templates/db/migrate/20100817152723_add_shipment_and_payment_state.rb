class AddShipmentAndPaymentState < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.string :shipment_state
      t.string :payment_state
    end
  end

  def self.down
    change_table :orders do |t|
      t.remove :shipment_state
      t.remove :payment_state
    end
  end
end
