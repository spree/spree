require 'spec_helper'

module Spree
  describe Fulfillments::MarkDelivered do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }

    before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

    it 'records receipt' do
      result = subject.call(fulfillment: fulfillment)

      expect(result.success?).to eq(true)
      expect(fulfillment.reload).to be_delivered
      expect(fulfillment.delivered_at).to be_present
    end

    # Carriers report a delivery time that is usually earlier than the webhook
    # announcing it, and the return window has to run from the real one.
    it 'honours a supplied delivery time' do
      arrived = 2.hours.ago

      subject.call(fulfillment: fulfillment, delivered_at: arrived)

      expect(fulfillment.reload.delivered_at).to be_within(1.second).of(arrived)
    end

    it 'rolls the order up to delivered when every parcel arrived' do
      subject.call(fulfillment: fulfillment)

      expect(order.reload.fulfillment_status).to eq('delivered')
    end

    describe 'guards' do
      it 'refuses a fulfillment that never shipped' do
        fulfillment.update!(status: 'unfulfilled')

        result = subject.call(fulfillment: fulfillment)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.cannot_mark_delivered'))
      end

      it 'refuses a canceled fulfillment' do
        fulfillment.update!(status: 'canceled')

        expect(subject.call(fulfillment: fulfillment).success?).to eq(false)
      end
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto the confirmation' do
        Spree.hooks.register('fulfillments.mark_delivered.validate') do |flow|
          flow.reject!('we confirm deliveries ourselves')
        end

        result = subject.call(fulfillment: fulfillment)

        expect(result.success?).to eq(false)
        expect(fulfillment.reload).to be_fulfilled
      end

      it 'notifies after_mark_delivered handlers' do
        observed = nil
        Spree.hooks.register('fulfillments.mark_delivered.after_mark_delivered') do |flow|
          observed = flow.fulfillment.status
        end

        subject.call(fulfillment: fulfillment)

        expect(observed).to eq('delivered')
      end
    end

    # A human saying "it arrived" outranks a carrier that never sent its
    # last scan: every open consignment closes with the fulfillment.
    it 'closes every open delivery at the same time' do
      second = Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: 'BOX-2').value
      arrived = 30.minutes.ago

      subject.call(fulfillment: fulfillment, delivered_at: arrived)

      expect(fulfillment.deliveries.reload.map(&:status).uniq).to eq(['delivered'])
      expect(second.reload.delivered_at).to be_within(1.second).of(arrived)
    end

    it 'works for a fulfillment with no delivery at all' do
      fulfillment.deliveries.destroy_all

      expect(subject.call(fulfillment: fulfillment)).to be_success
      expect(fulfillment.reload).to be_delivered
    end
  end
end
