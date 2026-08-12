require 'spec_helper'

module Spree
  describe Fulfillments::UpdateTracking do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }

    before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

    it 'records what the carrier reports' do
      result = subject.call(
        fulfillment: fulfillment,
        tracking_status: 'in_transit',
        estimated_delivery_at: 2.days.from_now,
        details: { 'last_scan' => 'Leipzig' }
      )

      expect(result.success?).to eq(true)
      expect(fulfillment.reload.tracking_status).to eq('in_transit')
      expect(fulfillment.estimated_delivery_at).to be_present
      expect(fulfillment.tracking_details).to eq('last_scan' => 'Leipzig')
    end

    it 'refuses a status outside the carrier vocabulary' do
      result = subject.call(fulfillment: fulfillment, tracking_status: 'teleported')

      expect(result.success?).to eq(false)
      expect(fulfillment.reload.tracking_status).to be_nil
    end

    # A webhook carrying only a scan must not wipe an estimate an earlier one
    # supplied.
    it 'leaves attributes the caller did not mention alone' do
      subject.call(fulfillment: fulfillment, estimated_delivery_at: 3.days.from_now)
      estimate = fulfillment.reload.estimated_delivery_at

      subject.call(fulfillment: fulfillment, tracking_status: 'out_for_delivery')

      expect(fulfillment.reload.estimated_delivery_at).to be_within(1.second).of(estimate)
    end

    describe 'when the carrier reports delivery' do
      it 'confirms receipt on the status axis too' do
        arrived = 1.hour.ago

        subject.call(fulfillment: fulfillment, tracking_status: 'delivered', delivered_at: arrived)

        expect(fulfillment.reload).to be_delivered
        expect(fulfillment.delivered_at).to be_within(1.second).of(arrived)
      end
    end

    # The whole point of the second axis: a parcel that bounces is still a
    # parcel the merchant handed over.
    describe 'when the carrier reports a problem' do
      it 'records the trouble without moving the fulfillment backwards' do
        subject.call(fulfillment: fulfillment, tracking_status: 'return_to_sender')

        expect(fulfillment.reload.tracking_status).to eq('return_to_sender')
        expect(fulfillment).to be_fulfilled
      end

      it 'records a failed delivery attempt the same way' do
        subject.call(fulfillment: fulfillment, tracking_status: 'failure')

        expect(fulfillment.reload).to be_fulfilled
        expect(order.reload.fulfillment_status).to eq('fulfilled')
      end
    end

    it 'ignores a delivery report for a canceled parcel' do
      fulfillment.update!(status: 'canceled')

      subject.call(fulfillment: fulfillment, tracking_status: 'delivered')

      expect(fulfillment.reload).to be_canceled
      expect(fulfillment.tracking_status).to eq('delivered')
    end
  end
end
