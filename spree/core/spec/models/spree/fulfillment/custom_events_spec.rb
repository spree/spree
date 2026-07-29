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
      fulfillment.fulfill!

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('shipment.shipped', anything, anything)
    end

    it 'does not publish when events are disabled' do
      allow(Spree::Events).to receive(:enabled?).and_return(false)

      fulfillment.fulfill!

      expect(Spree::Events).not_to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('shipment.shipped', anything, anything)
    end
  end

  describe 'fulfillment.canceled event' do
    it 'publishes fulfillment.canceled and dual-emits the legacy shipment.canceled' do
      fulfillment.cancel!

      expect(Spree::Events).to have_received(:publish).with('fulfillment.canceled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('shipment.canceled', anything, anything)
    end
  end

  describe 'order.fulfilled event' do
    it 'publishes order.fulfilled when the last fulfillment fulfills (plus legacy order.shipped)' do
      # The order_ready_to_ship factory creates an order with a single
      # fulfillment, so fulfilling it makes order.fully_fulfilled? true
      fulfillment.fulfill!

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.fulfilled', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.shipped', anything, anything)
    end

    it 'does not publish order.fulfilled when other fulfillments are open' do
      create(:shipment, order: order, state: 'pending')
      order.reload

      fulfillment.fulfill!

      expect(Spree::Events).to have_received(:publish).with('fulfillment.fulfilled', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('order.fulfilled', anything, anything)
    end
  end
end
