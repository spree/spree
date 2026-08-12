# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Fulfillment::CustomEvents do
  let(:order) { create(:order_ready_to_ship, line_items_count: 1) }
  let(:fulfillment) { order.fulfillments.first }

  before do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)
  end

  describe 'fulfillment.fulfilled event' do
    it 'publishes fulfillment.fulfilled and dual-emits the legacy shipment.shipped' do
      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('shipment.shipped', anything, anything)
    end

    it 'does not publish when events are disabled' do
      allow(Spree::Events).to receive(:enabled?).and_return(false)

      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(Spree::Events).not_to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('shipment.shipped', anything, anything)
    end
  end

  describe 'fulfillment.canceled event' do
    it 'publishes fulfillment.canceled and dual-emits the legacy shipment.canceled' do
      Spree.fulfillment_cancel_workflow.call(fulfillment: fulfillment)

      expect(Spree::Events).to have_received(:publish).with('fulfillment.canceled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('shipment.canceled', anything, anything)
    end
  end

  describe 'order.fulfilled event' do
    it 'publishes order.fulfilled when the last fulfillment fulfills (plus legacy order.shipped)' do
      # The order_ready_to_ship factory creates an order with a single
      # fulfillment, so fulfilling it makes order.fully_fulfilled? true
      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.shipped', anything, anything)
    end

    it 'does not publish order.fulfilled when other fulfillments are open' do
      create(:shipment, order: order, state: 'unfulfilled')
      order.reload

      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('order.fulfilled', anything, anything)
    end
  end

  describe 'fulfillment.delivered event' do
    it 'publishes when receipt is confirmed' do
      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(fulfillment).to receive(:publish_event).
        with('fulfillment.delivered', nil, hash_including(notify_customer: true))
      allow(fulfillment).to receive(:publish_event).with(any_args)

      fulfillment.publish_fulfillment_delivered_event
    end
  end
end
