require 'spec_helper'

module Spree
  describe Deliveries::UpdateTracking do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }
    let(:delivery) { fulfillment.deliveries.first }

    before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

    it 'records what the carrier reports' do
      result = subject.call(
        delivery: delivery,
        tracking_status: 'in_transit',
        estimated_delivery_at: 2.days.from_now,
        details: { 'last_scan' => 'Leipzig' }
      )

      expect(result.success?).to eq(true)
      expect(delivery.reload.status).to eq('in_transit')
      expect(delivery.estimated_delivery_at).to be_present
      expect(delivery.details).to eq('last_scan' => 'Leipzig')
    end

    it 'refuses a status outside the carrier vocabulary' do
      result = subject.call(delivery: delivery, tracking_status: 'teleported')

      expect(result.success?).to eq(false)
      expect(delivery.reload.status).to eq('pending')
    end

    # A webhook carrying only a scan must not wipe an estimate an earlier one
    # supplied.
    it 'leaves attributes the caller did not mention alone' do
      subject.call(delivery: delivery, estimated_delivery_at: 3.days.from_now)
      estimate = delivery.reload.estimated_delivery_at

      subject.call(delivery: delivery, tracking_status: 'out_for_delivery')

      expect(delivery.reload.estimated_delivery_at).to be_within(1.second).of(estimate)
    end

    describe 'when the carrier reports delivery' do
      it 'stamps the delivery and confirms receipt on the fulfillment' do
        arrived = 1.hour.ago

        subject.call(delivery: delivery, tracking_status: 'delivered', delivered_at: arrived)

        expect(delivery.reload.delivered_at).to be_within(1.second).of(arrived)
        expect(fulfillment.reload).to be_delivered
        expect(fulfillment.delivered_at).to be_within(1.second).of(arrived)
      end

      it 'waits for every consignment before the fulfillment is delivered' do
        second = Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: 'BOX-2').value

        subject.call(delivery: delivery, tracking_status: 'delivered', delivered_at: 2.hours.ago)
        expect(fulfillment.reload).to be_fulfilled

        subject.call(delivery: second, tracking_status: 'delivered', delivered_at: 1.hour.ago)
        expect(fulfillment.reload).to be_delivered
        expect(fulfillment.delivered_at).to be_within(1.second).of(1.hour.ago)
      end

      # Goods arriving is not goods inspected: Returns::Receive stays a staff act.
      it 'never transitions a return' do
        return_record = create(:return, order: create(:shipped_order, store: store))
        inbound = Spree::Deliveries::Create.new.call(owner: return_record, tracking_number: 'RET-1').value

        result = subject.call(delivery: inbound, tracking_status: 'delivered')

        expect(result).to be_success
        expect(inbound.reload).to be_delivered
        expect(return_record.reload).to be_requested
      end
    end

    # The whole point of the second axis: a parcel that bounces is still a
    # parcel the merchant handed over.
    describe 'when the carrier reports a problem' do
      it 'records the trouble without moving the fulfillment backwards' do
        subject.call(delivery: delivery, tracking_status: 'return_to_sender')

        expect(delivery.reload.status).to eq('return_to_sender')
        expect(fulfillment.reload).to be_fulfilled
      end

      it 'records a failed delivery attempt the same way' do
        subject.call(delivery: delivery, tracking_status: 'failure')

        expect(fulfillment.reload).to be_fulfilled
        expect(order.reload.fulfillment_status).to eq('fulfilled')
      end
    end

    it 'ignores a delivery report for a canceled parcel' do
      fulfillment.update!(status: 'canceled')

      subject.call(delivery: delivery, tracking_status: 'delivered')

      expect(fulfillment.reload).to be_canceled
      expect(delivery.reload.status).to eq('delivered')
    end
  end
end
