require 'spec_helper'

describe Spree::Shipment, type: :model do
  let(:order) { create(:order) }
  let(:shipping_method) { create(:shipping_method, name: 'UPS') }
  let(:shipment) { create(:shipment, cost: 1, status: 'pending', stock_location: create(:stock_location), order: order) }

  before do
    allow(order).to receive_messages backordered?: false,
                                     canceled?: false,
                                     can_ship?: true,
                                     paid?: false,
                                     touch_later: false

    allow(shipment).to receive_messages(delivery_method: shipping_method, shipping_method: shipping_method)
  end

  ['ready', 'canceled'].each do |status|
    context "from #{status}" do
      before do
        allow(order).to receive(:update_with_updater!)
        allow(shipment).to receive_messages(require_inventory: false, update_order: true, status: status)
      end

      it 'publishes shipment.shipped event when fulfilling', events: true do
        expect(shipment).to receive(:publish_event).
          with('shipment.shipped', nil, hash_including(notify_customer: true))
        allow(shipment).to receive(:publish_event).with(any_args)

        shipment.fulfill!
      end
    end
  end
end
