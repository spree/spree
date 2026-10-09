require 'spec_helper'

describe Spree::Fulfillment, type: :model do
  let(:shipment) { create(:fulfillment) }

  # The legacy shipment.* name is dual-emitted for one release, and the
  # email subscribers still listen for it.
  it 'publishes shipment.shipped event when fulfilling', events: true do
    expect(shipment).to receive(:publish_event).
      with('shipment.shipped', nil, hash_including(notify_customer: true))
    allow(shipment).to receive(:publish_event).with(any_args)

    shipment.publish_fulfillment_fulfilled_event
  end
end
