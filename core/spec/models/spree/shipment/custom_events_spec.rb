# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Shipment::CustomEvents do
  let(:order) { create(:order_ready_to_ship, line_items_count: 1) }
  let(:shipment) { order.shipments.first }

  before do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)
  end

  describe 'shipment.shipped event' do
    it 'publishes shipment.shipped when shipment state changes to shipped' do
      allow(order).to receive(:fully_shipped?).and_return(false)

      shipment.ship!

      expect(Spree::Events).to have_received(:publish).with('shipment.shipped', anything, anything)
    end

    it 'does not publish when events are disabled' do
      allow(Spree::Events).to receive(:enabled?).and_return(false)

      shipment.ship!

      expect(Spree::Events).not_to have_received(:publish).with('shipment.shipped', anything, anything)
    end
  end

  describe 'order.shipped event' do
    it 'publishes order.shipped when shipment ships and order is fully shipped' do
      # The order_ready_to_ship factory creates an order with a single shipment,
      # so when that shipment ships, order.fully_shipped? returns true
      shipment.ship!

      expect(Spree::Events).to have_received(:publish).with('shipment.shipped', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.shipped', anything, anything)
    end

    it 'does not publish order.shipped when order has unshipped shipments' do
      # Create a second shipment that won't be shipped
      create(:shipment, order: order, state: 'pending')
      order.reload

      shipment.ship!

      expect(Spree::Events).to have_received(:publish).with('shipment.shipped', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('order.shipped', anything, anything)
    end
  end
end
