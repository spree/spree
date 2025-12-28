require 'spec_helper'

describe Spree::Shipment, type: :model do
  let(:order) { create(:order) }
  let(:shipping_method) { create(:shipping_method, name: 'UPS') }
  let(:shipment) { create(:shipment, cost: 1, state: 'pending', stock_location: create(:stock_location), order: order) }

  before do
    allow(order).to receive_messages backordered?: false,
                                     canceled?: false,
                                     can_ship?: true,
                                     paid?: false,
                                     touch_later: false

    allow(shipment).to receive_messages shipping_method: shipping_method
  end

  ['ready', 'canceled'].each do |state|
    context "from #{state}" do
      before do
        allow(order).to receive(:update_with_updater!)
        allow(shipment).to receive_messages(require_inventory: false, update_order: true, state: state)
      end

      it 'publishes shipment.shipped event when shipping' do
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)

        expect(shipment).to receive(:publish_event).with('shipment.shipped')
        allow(shipment).to receive(:publish_event).with(anything)

        shipment.ship!
      end
    end
  end
end
